# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollaborativeEditing::WikiPageChannel, :clean_gitlab_redis_shared_state,
  :with_current_organization, feature_category: :wiki do
  let_it_be_with_reload(:project) { create(:project, :private, :wiki_repo) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:stranger) { create(:user) }

  let_it_be(:page) do
    create(:wiki_page, wiki: project.wiki, title: 'home', content: 'Hello').tap(&:last_commit_sha)
  end

  let(:subscribe_params) do
    { container_full_path: project.full_path, slug: page.slug, last_commit_sha: page.last_commit_sha }
  end

  let(:document_key) { "wiki:Project:#{project.id}:#{CGI.escape(page.slug)}" }
  let(:stream_name) do
    "collaborative_editing:#{document_key}:#{store_for(page).open(version: page.last_commit_sha).session_id}"
  end

  before do
    stub_action_cable_connection current_user: developer, current_organization: current_organization
  end

  describe '#subscribed' do
    it 'does not let a returning client consume an empty session seed claim', :aggregate_failures do
      session = store_for(page).open(version: page.last_commit_sha)
      subscribe(subscribe_params, initialise: false)
      perform :initialize_session, { version: 'stale', sessionId: session.session_id }
      deliver_readiness
      expect(transmissions.last).to include('type' => 'init', 'updates' => [], 'seed' => false)

      subscribe(subscribe_params)

      expect(transmissions.last).to include('type' => 'init', 'updates' => [], 'seed' => true)
    end

    it 'does not let a refused client consume the seed claim', :aggregate_failures do
      subscribe(subscribe_params, initialise: false)
      perform :initialize_session, { version: 'stale' }
      deliver_readiness
      expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'page_changed')

      subscribe(subscribe_params)

      expect(transmissions.last).to include('type' => 'init', 'updates' => [], 'seed' => true)
    end

    it 'asks a joiner to recover while a save is changing the bound version', :aggregate_failures do
      existing = store_for(page)
      session = existing.open(version: page.last_commit_sha)
      marker = { session_id: session.session_id, save_id: 'saving', user_id: developer.id }
      existing.claim_save(**marker)
      existing.confirm_save(**marker, version: page.last_commit_sha)
      Gitlab::Redis::SharedState.with do |redis|
        redis.hset("collaborative_editing:{#{document_key}}:session", 'version', 'previous')
      end

      subscribe(subscribe_params)

      expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'lookup_failed')
    end

    it 'admits a returning generation even when its rendered SHA is stale', :aggregate_failures do
      session = store_for(page).open(version: page.last_commit_sha)
      subscribe(subscribe_params, initialise: false)
      perform :initialize_session, { version: 'old', sessionId: session.session_id }
      deliver_readiness

      expect(transmissions.last).to include('type' => 'init', 'version' => page.last_commit_sha)
    end

    initialisation_phases = %w[marker periodic]
    %i[blob_at last_commit_for_path].each do |lookup_method|
      context "when #{lookup_method} fails" do
        it 'reports an indeterminate initial page lookup without opening a store', :aggregate_failures do
          parameters = subscribe_params
          fail_next_page_lookup(lookup_method)
          expect(Gitlab::CollaborativeEditing::DocumentStore).not_to receive(:new)

          subscribe(parameters)

          expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'lookup_failed')
          expect(subscription).not_to have_streams
        end

        initialisation_phases.each do |phase|
          it "stops initialisation when lookup fails at the #{phase}", :aggregate_failures do
            subscribe(subscribe_params, initialise: false)
            perform :initialize_session, { version: page.last_commit_sha } if phase == 'marker'
            expect(subscription.send(:store)).not_to receive(:read_session)
            fail_next_page_lookup(lookup_method)

            phase == 'marker' ? deliver_readiness : revalidate

            expect(transmissions).to eq([{ 'type' => 'session_invalidated', 'reason' => 'lookup_failed' }])
            expect(subscription.send(:store)).to be_nil
          end
        end
      end
    end

    it 'waits for its own readiness marker and ignores foreign or duplicate markers', :aggregate_failures do
      stream_callback = nil
      allow_next_instance_of(described_class) do |channel|
        channel.singleton_class.include(ActionCable::Channel::ChannelStub)
        allow(channel).to receive(:stream_from).and_wrap_original do |original, *args, **kwargs, &block|
          stream_callback = block
          original.call(*args, **kwargs, &block)
        end
      end
      subscribe(subscribe_params, initialise: false)
      store_for(page).append('accepted-before-confirmation')
      allow(ActionCable.server).to receive(:broadcast).and_call_original
      perform :initialize_session, { version: page.last_commit_sha }
      expect(transmissions).to be_empty
      own_token = subscription.instance_variable_get(:@readiness_token)
      expect(ActionCable.server).to have_received(:broadcast)
        .with(subscription.send(:stream_name), { type: 'session_ready', token: own_token })
      stream_callback.call({ 'type' => 'session_ready', 'token' => 'foreign' })
      expect(transmissions).to be_empty
      store_for(page).append('accepted-before-marker')

      stream_callback.call({ 'type' => 'session_ready', 'token' => own_token })
      stream_callback.call({ 'type' => 'session_ready', 'token' => own_token })

      expect(transmissions.size).to eq(1)
      expect(transmissions.last).to include('type' => 'init',
        'updates' => %w[accepted-before-confirmation accepted-before-marker])
      update = { 'type' => 'sync', 'payload' => 'live-update', 'clientId' => 2 }
      stream_callback.call(update)

      expect(transmissions.last).to eq(update)
    end

    it 'checks access again when its readiness marker arrives', :aggregate_failures do
      subscribe(subscribe_params, initialise: false)
      perform :initialize_session, { version: page.last_commit_sha }
      session_store = subscription.send(:store)
      stub_feature_flags(wiki_collaborative_editing: false)
      expect(session_store).not_to receive(:read_session)

      deliver_readiness
      subscription.send(:receive_stream_message, { 'type' => 'sync', 'payload' => 'late', 'clientId' => 2 })

      expect(transmissions).to be_empty
      expect(subscription.send(:store)).to be_nil
    end

    it 'rejects a generation lost after readiness revalidation but before replay', :aggregate_failures do
      subscribe(subscribe_params, initialise: false)
      perform :initialize_session, { version: page.last_commit_sha }
      expect(subscription.send(:store)).to receive(:read_session).and_wrap_original do |original, **kwargs|
        Gitlab::Redis::SharedState.with { |redis| redis.del("collaborative_editing:{#{document_key}}:session") }
        original.call(**kwargs)
      end

      deliver_readiness

      expect(transmissions).to eq([{ 'type' => 'session_invalidated', 'reason' => 'session_expired' }])
      expect(subscription.send(:store)).to be_nil
      expect(Gitlab::Redis::SharedState.with do |redis|
        redis.exists?("collaborative_editing:{#{document_key}}:session")
      end)
        .to be(false)
    end

    it 'fails closed if the generation changes before confirmed-stream initialisation', :aggregate_failures do
      subscribe(subscribe_params, initialise: false)
      Gitlab::Redis::SharedState.with { |redis| redis.del("collaborative_editing:{#{document_key}}:session") }
      store_for(page)

      perform :initialize_session, { version: page.last_commit_sha }
      deliver_readiness

      expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'session_expired')
    end

    it 'reads the log only once per subscription', :aggregate_failures do
      subscribe(subscribe_params, initialise: false)
      expect(subscription.send(:store)).to receive(:read_session).once.and_call_original

      perform :initialize_session, { version: page.last_commit_sha }
      deliver_readiness
      perform :initialize_session, { version: page.last_commit_sha }

      expect(transmissions.count { |message| message['type'] == 'init' }).to eq(1)
    end

    it 'subscribes a user who can edit the wiki' do
      subscribe(subscribe_params)

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from(stream_name)
    end

    it 'sends the existing update log to the joining client' do
      store_for(page).append('existing-update')

      subscribe(subscribe_params)

      expect(transmissions.last).to include('type' => 'init', 'updates' => ['existing-update'])
    end

    describe 'feature flag scope' do
      context 'when the flag is disabled' do
        before do
          stub_feature_flags(wiki_collaborative_editing: false)
        end

        it 'rejects the subscription' do
          subscribe(subscribe_params)

          expect(subscription).to be_rejected
        end
      end

      it 'is scoped to the root ancestor of the container' do
        stub_feature_flags(wiki_collaborative_editing: project.root_ancestor)

        subscribe(subscribe_params)

        expect(subscription).to be_confirmed
      end
    end

    context 'when the user cannot edit the wiki' do
      before do
        stub_action_cable_connection current_user: guest, current_organization: current_organization
      end

      it 'rejects the subscription' do
        subscribe(subscribe_params)

        expect(subscription).to be_rejected
      end
    end

    context 'when the user cannot read the project' do
      before do
        stub_action_cable_connection current_user: stranger, current_organization: current_organization
      end

      it 'rejects the subscription' do
        subscribe(subscribe_params)

        expect(subscription).to be_rejected
      end

      it 'rejects before looking the page up' do
        expect(ProjectWiki).not_to receive(:new)

        subscribe(subscribe_params)

        expect(subscription).to be_rejected
      end
    end

    context 'when the page does not exist' do
      it 'ends the session as changed' do
        subscribe(container_full_path: project.full_path, slug: 'does-not-exist')

        expect(transmissions.last).to include('type' => 'session_invalidated', 'reason' => 'page_changed')
      end
    end

    context 'when the container does not exist' do
      it 'rejects the subscription' do
        subscribe(container_full_path: 'no/such/project', slug: page.slug)

        expect(subscription).to be_rejected
      end
    end

    context 'when the container has no wiki' do
      it 'rejects the subscription' do
        subscribe(container_full_path: developer.username, slug: page.slug)

        expect(subscription).to be_rejected
      end
    end

    context 'when params are missing' do
      it 'rejects the subscription' do
        subscribe({})

        expect(subscription).to be_rejected
      end
    end

    describe 'seed election' do
      it 'elects the first subscriber to seed an empty document' do
        subscribe(subscribe_params)

        expect(transmissions.last).to include('seed' => true)
      end

      it 'does not elect a second subscriber' do
        subscribe(subscribe_params)
        subscribe(subscribe_params)

        expect(transmissions.last).to include('seed' => false)
      end

      it 'does not elect a subscriber when the document already has updates' do
        store_for(page).append('existing-update')

        subscribe(subscribe_params)

        expect(transmissions.last).to include('seed' => false)
      end
    end

    [nil, '', 'stale-commit'].each do |sha|
      it "invalidates an initial subscription with #{sha.inspect} page version", :aggregate_failures do
        subscribe(subscribe_params, initialise: false)
        perform :initialize_session, { version: sha }
        deliver_readiness

        expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'page_changed')
        expect(subscription).not_to have_streams
        expect(subscription.send(:store)).to be_nil
      end
    end

    it 'isolates replacement generations even at the same Git commit', :aggregate_failures do
      subscribe(subscribe_params)
      old_stream = subscription.send(:stream_name)
      perform :receive, message('sync', 'accepted')
      Gitlab::Redis::SharedState.with do |redis|
        redis.del("collaborative_editing:{#{document_key}}:updates")
      end

      replacement = store_for(page).open(version: page.last_commit_sha)

      expect(old_stream).not_to end_with(":#{replacement.session_id}")
      expect { perform :receive, message('sync', 'old delta') }.not_to have_broadcasted_to(old_stream)
      expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'session_expired')
    end

    context 'with a slug containing Redis Cluster hash tag characters' do
      let_it_be(:braced_page) do
        create(:wiki_page, wiki: project.wiki, title: 'we{ir}d', content: 'Hello').tap(&:last_commit_sha)
      end

      it 'escapes the slug so the key carries no braces', :aggregate_failures do
        key = "wiki:Project:#{project.id}:#{CGI.escape(braced_page.slug)}"
        generation = store_for(braced_page).open(version: braced_page.last_commit_sha).session_id
        escaped = "collaborative_editing:#{key}:#{generation}"

        subscribe(container_full_path: project.full_path, slug: braced_page.slug,
          last_commit_sha: braced_page.last_commit_sha)

        expect(braced_page.slug).to include('{', '}')
        expect(escaped).not_to include('{', '}')
        expect(subscription).to have_stream_from(escaped)
      end

      it 'keeps the document distinct from a similarly named page', :aggregate_failures do
        store_for(braced_page).append('braced-update')

        subscribe(subscribe_params)

        expect(transmissions.last).to include('updates' => [])
      end
    end

    context 'with a wiki page of the same slug in another project' do
      let_it_be_with_reload(:other_project) { create(:project, :private, :wiki_repo, developers: developer) }
      let_it_be(:other_page) do
        create(:wiki_page, wiki: other_project.wiki, title: 'home', content: 'Other').tap(&:last_commit_sha)
      end

      it 'uses a separate document so content does not leak between projects' do
        store_for(other_page).append('other-project-update')

        subscribe(subscribe_params)

        expect(transmissions.last).to include('updates' => [])
      end
    end

    context 'with a legacy personal access token' do
      it 'rejects a token that only carries read_api' do
        token = create(:personal_access_token, scopes: ['read_api'], user: developer)
        stub_action_cable_connection current_user: developer, access_token: token,
          current_organization: current_organization

        subscribe(subscribe_params)

        expect(subscription).to be_rejected
      end

      it 'accepts a token carrying api' do
        token = create(:personal_access_token, scopes: ['api'], user: developer)
        stub_action_cable_connection current_user: developer, access_token: token,
          current_organization: current_organization

        subscribe(subscribe_params)

        expect(subscription).to be_confirmed
      end
    end

    context 'with a granular personal access token' do
      let(:pat) do
        create(:granular_pat, user: developer, boundary: Authz::Boundary.for(project),
          permissions: :create_wiki)
      end

      it 'subscribes when the token carries create_wiki' do
        stub_action_cable_connection current_user: developer, access_token: pat,
          current_organization: current_organization

        subscribe(subscribe_params)

        expect(subscription).to be_confirmed
      end

      context 'when the token does not carry create_wiki' do
        let(:pat) do
          create(:granular_pat, user: developer, boundary: Authz::Boundary.for(project),
            permissions: :read_wiki)
        end

        it 'rejects the subscription' do
          stub_action_cable_connection current_user: developer, access_token: pat,
            current_organization: current_organization

          subscribe(subscribe_params)

          expect(subscription).to be_rejected
        end
      end

      context 'when the token is scoped to another project' do
        let_it_be(:other_project) { create(:project, :private, developers: developer) }
        let(:pat) do
          create(:granular_pat, user: developer, boundary: Authz::Boundary.for(other_project),
            permissions: :create_wiki)
        end

        it 'rejects the subscription' do
          stub_action_cable_connection current_user: developer, access_token: pat,
            current_organization: current_organization

          subscribe(subscribe_params)

          expect(subscription).to be_rejected
        end
      end
    end
  end

  describe 'periodic access revalidation' do
    before do
      subscribe(subscribe_params)
    end

    %i[blob_at last_commit_for_path].each do |lookup_method|
      context "when #{lookup_method} fails" do
        it 'keeps the existing generation alive and retries an indeterminate lookup', :aggregate_failures do
          existing_store = subscription.send(:store)
          expected_stream = stream_name
          expect(existing_store).to receive(:touch).twice.and_call_original
          fail_next_page_lookup(lookup_method)

          revalidate

          expect(transmissions.last).to include('type' => 'init')
          expect(subscription).to have_stream_from(expected_stream)
          revalidate

          expect { perform :receive, message('sync', 'still accepted') }.to have_broadcasted_to(expected_stream)
          expect(transmissions).not_to include(hash_including('type' => 'session_invalidated'))
        end

        it 'does not revive an expired generation while lookup is unavailable', :aggregate_failures do
          Gitlab::Redis::SharedState.with { |redis| redis.del("collaborative_editing:{#{document_key}}:session") }
          fail_next_page_lookup(lookup_method)

          revalidate

          expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'session_expired')
          expect(subscription.send(:store)).to be_nil
        end
      end
    end

    it 'is scheduled for every subscriber' do
      expect(described_class.periodic_timers.map(&:last)).to include({ every: 1.minute })
    end

    it 'keeps relaying for a subscriber who still has access', :aggregate_failures do
      revalidate

      expect { perform :receive, message('sync', 'an-update') }
        .to have_broadcasted_to(stream_name)

      expect(store_for(page).updates).to eq(['an-update'])
    end

    it 'keeps an idle, unseeded session alive', :aggregate_failures do
      session_store = subscription.send(:store)

      expect(session_store).to receive(:touch).with(session_id: anything, version: anything).and_call_original

      revalidate

      expect(transmissions.last).to include('type' => 'init')
    end

    context 'with writes to the wiki repository' do
      let_it_be_with_reload(:project) { create(:project, :private, :wiki_repo, developers: developer) }
      let(:page) { create(:wiki_page, wiki: project.wiki, content: 'Hello') }

      it 'invalidates a session after the page changes', :aggregate_failures do
        changed_page = project.wiki.find_page(page.slug)
        expect(changed_page.update(content: 'Saved through another writer')).to be(true)

        revalidate

        expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'page_changed')
        expect { perform :receive, message('sync', 'stale') }.not_to have_broadcasted_to(stream_name)
      end

      it 'waits for an in-flight collaborative save and keeps the generation after advancement', :aggregate_failures do
        existing = subscription.send(:store)
        session_id = transmissions.last.fetch('sessionId')
        expected_stream = existing.stream_name(session_id)
        marker = { session_id: session_id, save_id: 'save', user_id: developer.id }
        version = page.last_commit_sha
        expect(existing.claim_save(**marker)).to be(true)
        expect(existing.confirm_save(**marker, version: version)).to be(true)
        updated = project.wiki.find_page(page.slug)
        expect(updated.update(content: 'Collaborative save')).to be(true)

        revalidate

        expect(transmissions.last).to include('type' => 'init')
        expect(existing.advance_version(**marker, previous_version: version,
          version: updated.saved_commit_sha)).to be(true)
        revalidate
        expect { perform :receive, message('sync', 'later') }.to have_broadcasted_to(expected_stream)
      end

      it 'does not split a session for a commit to another page' do
        create(:wiki_page, wiki: project.wiki, title: 'unrelated', content: 'Unrelated')

        revalidate

        expect { perform :receive, message('sync', 'still accepted') }.to have_broadcasted_to(stream_name)
      end

      it 'invalidates a session after the page is deleted' do
        project.wiki.find_page(page.slug).delete

        revalidate

        expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'page_changed')
      end

      it 'invalidates a session after the page is renamed' do
        expect(project.wiki.find_page(page.slug).update(title: 'renamed', content: 'Renamed')).to be(true)

        revalidate

        expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'page_changed')
      end
    end

    %w[sync snapshot].each do |type|
      it "does not recreate a log lost while an editor sends #{type}", :aggregate_failures do
        perform :receive, message('sync', 'accepted')
        Gitlab::Redis::SharedState.with do |redis|
          redis.del("collaborative_editing:{#{document_key}}:updates")
        end

        expect { perform :receive, message(type, 'orphan delta').merge('token' => 'claim') }
          .not_to have_broadcasted_to(stream_name)
        expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'session_expired')
        expect(subscription.send(:store)).to be_nil
      end
    end

    context 'when the user loses access to the container' do
      before do
        project.members.find_by(user_id: developer.id).destroy!
      end

      it 'unsubscribes them' do
        expect(subscription).to receive(:unsubscribe_from_channel)
        expect(subscription).not_to receive(:find_document)
        expect(subscription.send(:store)).not_to receive(:touch)

        revalidate
      end

      it 'stops relaying their updates', :aggregate_failures do
        revalidate

        expect { perform :receive, message('sync', 'an-update') }
          .not_to have_broadcasted_to(stream_name)

        expect(store_for(page).updates).to be_empty
      end
    end

    context 'when the feature flag is turned off mid-session' do
      before do
        stub_feature_flags(wiki_collaborative_editing: false)
      end

      it 'unsubscribes them' do
        expect(subscription).to receive(:unsubscribe_from_channel)

        revalidate
      end

      it 'stops relaying their updates' do
        revalidate

        expect { perform :receive, message('sync', 'an-update') }
          .not_to have_broadcasted_to(stream_name)
      end
    end

    it 'does not revalidate a channel that has already been unsubscribed' do
      subscription.unsubscribe_from_channel

      expect(subscription).not_to receive(:feature_enabled?)

      revalidate
    end
  end

  describe 'unsubscribing' do
    before do
      subscribe(subscribe_params)
    end

    it 'stops relaying updates', :aggregate_failures do
      subscription.unsubscribe_from_channel

      expect { perform :receive, message('sync', 'an-update') }
        .not_to have_broadcasted_to(stream_name)

      expect(store_for(page).updates).to be_empty
    end

    context 'when authentication fails mid-session' do
      before do
        allow(subscription).to receive(:validate_and_save_access_token!)
          .and_raise(Gitlab::Auth::AuthenticationError)
      end

      it 'stops relaying updates', :aggregate_failures do
        subscription.send(:validate_user_authorization)

        expect { perform :receive, message('sync', 'an-update') }
          .not_to have_broadcasted_to(stream_name)

        expect(store_for(page).updates).to be_empty
      end
    end
  end

  describe '#receive' do
    before do
      subscribe(subscribe_params)
    end

    it 'acknowledges a save barrier once and broadcasts its pairing identifier', :aggregate_failures do
      first = message('sync', 'state').merge('saveId' => 'save-one', 'messageId' => 1)
      expect { perform :receive, first }.to have_broadcasted_to(stream_name)
        .with(hash_including('saveId' => 'save-one'))
      expect(transmissions.last).to eq('type' => 'ack', 'messageId' => 1, 'saveAccepted' => true)
      perform :receive, first.merge('saveId' => 'save-two', 'messageId' => 2)
      expect(transmissions.last).to eq('type' => 'ack', 'messageId' => 2, 'saveAccepted' => false)
    end

    it 'ignores malformed save identifiers', :aggregate_failures do
      expect { perform :receive, message('sync', 'state').merge('saveId' => 'bad:id', 'messageId' => 1) }
        .to have_broadcasted_to(stream_name).with(->(value) { expect(value).not_to have_key('saveId') })
      expect(transmissions.last).to eq('type' => 'ack', 'messageId' => 1)
    end

    it 'does not relay save identifiers attached to awareness' do
      expect { perform :receive, message('awareness', 'cursor').merge('saveId' => { 'unbounded' => 'value' }) }
        .to have_broadcasted_to(stream_name).with(->(value) { expect(value).not_to have_key('saveId') })
    end

    %w[sync snapshot].each do |type|
      it "rejects a #{type} from another generation before accessing the store", :aggregate_failures do
        session_store = subscription.send(:store)
        expect(session_store).not_to receive(:append)
        expect(session_store).not_to receive(:replace)

        perform :receive, message(type, 'stale').merge('sessionId' => 'wrong', 'token' => 'claim')

        expect(transmissions.last).to eq('type' => 'session_invalidated', 'reason' => 'session_expired')
        expect(subscription.send(:store)).to be_nil
      end
    end

    it 'persists and broadcasts a sync update' do
      expect { perform :receive, message('sync', 'an-update') }
        .to have_broadcasted_to(stream_name)
        .with(hash_including('type' => 'sync', 'payload' => 'an-update'))

      expect(store_for(page).updates).to eq(['an-update'])
    end

    it 'acknowledges a sync only after persisting it', :aggregate_failures do
      expect(subscription.send(:store)).to receive(:append)
        .with('an-update', session_id: anything).ordered.and_call_original
      expect(subscription).to receive(:transmit).with({ type: 'ack', messageId: 12 }).ordered.and_call_original

      perform :receive, message('sync', 'an-update').merge('messageId' => 12)

      expect(transmissions.last).to eq({ 'type' => 'ack', 'messageId' => 12 })
      expect(store_for(page).updates).to eq(['an-update'])
    end

    it 'broadcasts awareness without persisting it' do
      expect { perform :receive, message('awareness', 'cursor-position') }
        .to have_broadcasted_to(stream_name)
        .with(hash_including('type' => 'awareness'))

      expect(store_for(page).updates).to be_empty
    end

    describe 'identity on an awareness relay' do
      it 'stamps the sender identity from the session' do
        expect { perform :receive, message('awareness', 'cursor-position') }
          .to have_broadcasted_to(stream_name)
          .with(
            hash_including(
              'user' => {
                id: developer.id,
                name: developer.name,
                avatarUrl: developer.avatar_url(only_path: false)
              }
            )
          )
      end

      it 'ignores an identity supplied by the sender' do
        spoofed = message('awareness', 'cursor-position')
          .merge('user' => { 'name' => 'Administrator', 'avatarUrl' => 'https://evil.test/beacon' })

        expect { perform :receive, spoofed }
          .to have_broadcasted_to(stream_name)
          .with(hash_including('user' => hash_including(name: developer.name)))
      end

      it 'does not stamp identity onto a sync relay' do
        expect { perform :receive, message('sync', 'an-update') }
          .to have_broadcasted_to(stream_name)
          .with(->(payload) { expect(payload).not_to have_key('user') })
      end
    end

    it 'ignores a payload that is not a string' do
      expect { perform :receive, { 'type' => 'sync', 'payload' => { 'a' => 'b' } } }
        .not_to have_broadcasted_to(stream_name)
    end

    it 'stops only the sender when a sync payload is too large to persist', :aggregate_failures do
      stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
      oversized = 'a' * (Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES + 1)

      expect { perform :receive, message('sync', oversized) }
        .not_to have_broadcasted_to(stream_name)

      expect(transmissions.last).to eq('type' => 'payload_too_large')
      expect(store_for(page).updates).to be_empty
    end

    it 'does not notify a rate-limited sender for an oversized sync', :aggregate_failures do
      stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
      oversized = 'a' * (Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES + 1)
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)

      expect { perform :receive, message('sync', oversized) }.not_to have_broadcasted_to(stream_name)
      expect(transmissions).not_to include(hash_including('type' => 'payload_too_large'))
    end

    it 'accepts a full-state sync above the awareness limit', :aggregate_failures do
      stub_const('CollaborativeEditing::BaseChannel::MAX_PAYLOAD_BYTES', 5)
      payload = 'a' * (described_class.superclass::MAX_PAYLOAD_BYTES + 1)

      expect { perform :receive, message('sync', payload).merge('messageId' => 17) }
        .to have_broadcasted_to(stream_name).with(hash_including('type' => 'sync', 'payload' => payload))

      expect(transmissions.last).to eq('type' => 'ack', 'messageId' => 17)
      expect(store_for(page).updates).to eq([payload])
    end

    it 'ignores awareness above its own size limit', :aggregate_failures do
      stub_const('CollaborativeEditing::BaseChannel::MAX_PAYLOAD_BYTES', 5)
      payload = 'a' * (described_class.superclass::MAX_PAYLOAD_BYTES + 1)

      expect { perform :receive, message('awareness', payload) }.not_to have_broadcasted_to(stream_name)

      expect(transmissions).not_to include(hash_including('type' => 'payload_too_large'))
      expect(store_for(page).updates).to be_empty
    end

    it 'accepts a sync at the document byte limit', :aggregate_failures do
      stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
      payload = 'a' * Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES

      expect { perform :receive, message('sync', payload).merge('messageId' => 17) }
        .to have_broadcasted_to(stream_name).with(hash_including('type' => 'sync', 'payload' => payload))

      expect(transmissions).to include('type' => 'ack', 'messageId' => 17)
      expect(store_for(page).updates).to eq([payload])
    end

    it 'requests compaction when a full-state sync cannot fit the existing log', :aggregate_failures do
      stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
      perform :receive, message('sync', 'old')

      expect { perform :receive, message('sync', '12345678').merge('messageId' => 17) }
        .not_to have_broadcasted_to(stream_name)

      expect(transmissions).to include('type' => 'document_full', 'messageId' => 17)
      expect(transmissions.last).to include('type' => 'request_snapshot')
      expect(transmissions).not_to include('type' => 'ack', 'messageId' => 17)
      expect(store_for(page).updates).to eq(['old'])
    end

    it 'ignores an unknown message type' do
      expect { perform :receive, message('nonsense', 'a-payload') }
        .not_to have_broadcasted_to(stream_name)
    end

    [{ 'a' => 'b' }, %w[1 2], 'not-a-number', nil].each do |client_id|
      it "ignores a message whose clientId is #{client_id.class}" do
        expect { perform :receive, message('sync', 'an-update').merge('clientId' => client_id) }
          .not_to have_broadcasted_to(stream_name)
      end
    end

    it 'does not store a message with a rejected clientId' do
      perform :receive, message('sync', 'an-update').merge('clientId' => { 'a' => 'b' })

      expect(store_for(page).updates).to be_empty
    end

    it 'does not acknowledge an invalid sync payload' do
      perform :receive, message('sync', 123).merge('messageId' => 16)

      expect(transmissions).not_to include(hash_including('type' => 'ack'))
    end

    describe 'compaction' do
      before do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::COMPACTION_THRESHOLD', 2)
      end

      it 'asks the sender for a snapshot once the log grows too long', :aggregate_failures do
        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')

        expect(transmissions.last).to include('type' => 'request_snapshot')
        expect(transmissions.last['token']).to be_present
      end

      it 'replaces the log with a snapshot', :aggregate_failures do
        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')
        token = transmissions.last['token']

        perform :receive, message('snapshot', 'a-snapshot').merge('token' => token)

        expect(store_for(page).updates).to eq(['a-snapshot'])
      end

      it 'acknowledges an accepted snapshot' do
        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')
        token = transmissions.last['token']

        perform :receive, message('snapshot', 'a-snapshot').merge('token' => token, 'messageId' => 13)

        expect(transmissions.last).to eq({ 'type' => 'ack', 'messageId' => 13 })
      end

      it 'reports a failed compaction only to its sender without broadcasting or acknowledging', :aggregate_failures do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
        perform :receive, message('sync', 'one')
        perform :receive, message('sync', 'two')
        token = transmissions.last['token']
        perform :receive, message('sync', 'end')

        expect { perform :receive, message('snapshot', '12345678').merge('token' => token, 'messageId' => 13) }
          .not_to have_broadcasted_to(stream_name)
        expect(transmissions.last).to eq('type' => 'document_full', 'messageId' => 13)
        expect(transmissions).not_to include('type' => 'ack', 'messageId' => 13)
        expect(store_for(page).updates).to eq(%w[one two end])
      end

      it 'keeps the compaction claim after rejecting a snapshot', :aggregate_failures do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
        perform :receive, message('sync', 'one')
        perform :receive, message('sync', 'two')
        token = transmissions.last['token']
        perform :receive, message('sync', 'end')
        perform :receive, message('snapshot', '12345678').merge('token' => token)

        expect { perform :receive, message('snapshot', '12345678').merge('token' => token) }
          .not_to have_broadcasted_to(stream_name)
        perform :receive, message('sync', 'x').merge('messageId' => 14)

        expect(transmissions.last).to eq('type' => 'ack', 'messageId' => 14)
        expect(transmissions.count { |entry| entry['type'] == 'request_snapshot' }).to eq(1)
        expect(store_for(page).updates).to eq(%w[one two end x])
      end

      it 'accepts a snapshot above the awareness size limit when it fits the byte budget', :aggregate_failures do
        stub_const('CollaborativeEditing::BaseChannel::MAX_PAYLOAD_BYTES', 5)
        perform :receive, message('sync', 'one')
        perform :receive, message('sync', 'two')
        token = transmissions.last['token']
        oversized = 'a' * (described_class.superclass::MAX_PAYLOAD_BYTES + 1)

        expect { perform :receive, message('snapshot', oversized).merge('token' => token) }
          .to have_broadcasted_to(stream_name).with(hash_including('type' => 'sync', 'payload' => oversized))
        expect(store_for(page).updates).to eq([oversized])
      end

      it 'accepts a snapshot at the document byte limit', :aggregate_failures do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
        perform :receive, message('sync', 'one')
        perform :receive, message('sync', 'two')
        token = transmissions.last['token']
        snapshot = 'a' * Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES

        expect { perform :receive, message('snapshot', snapshot).merge('token' => token) }
          .to have_broadcasted_to(stream_name).with(hash_including('type' => 'sync', 'payload' => snapshot))
        expect(store_for(page).updates).to eq([snapshot])
      end

      it 'rejects only the sender for a snapshot above the document budget', :aggregate_failures do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
        perform :receive, message('sync', 'one')
        perform :receive, message('sync', 'two')
        token = transmissions.last['token']
        oversized = 'a' * (Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES + 1)

        expect { perform :receive, message('snapshot', oversized).merge('token' => token) }
          .not_to have_broadcasted_to(stream_name)
        expect(transmissions.last).to eq('type' => 'payload_too_large')
        expect(store_for(page).updates).to eq(%w[one two])
      end

      it 'does not store an oversized unclaimed snapshot' do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
        oversized = 'a' * (Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES + 1)

        perform :receive, message('snapshot', oversized).merge('token' => 'forged')

        expect(store_for(page).updates).to be_empty
      end

      it 'allows a later subscriber to compact after a failed claim expires', :aggregate_failures do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
        perform :receive, message('sync', 'one')
        perform :receive, message('sync', 'two')
        token = transmissions.last['token']
        perform :receive, message('sync', 'end')
        perform :receive, message('snapshot', '12345678').merge('token' => token)
        Gitlab::Redis::SharedState.with do |redis|
          redis.del("collaborative_editing:{#{document_key}}:compaction")
        end
        subscribe(subscribe_params)

        expect(subscription).to be_confirmed
        expect(transmissions.last).to include('type' => 'init', 'updates' => %w[one two end])
        perform :receive, message('sync', 'xx').merge('messageId' => 14)
        retry_token = transmissions.last['token']

        expect(transmissions).to include('type' => 'document_full', 'messageId' => 14)
        expect(retry_token).to be_present
        expect(retry_token).not_to eq(token)
        perform :receive, message('snapshot', 'small').merge('token' => retry_token, 'messageId' => 15)
        perform :receive, message('sync', 'next').merge('messageId' => 16)

        expect(transmissions).to include('type' => 'ack', 'messageId' => 15)
        expect(transmissions).to include('type' => 'ack', 'messageId' => 16)
        expect(store_for(page).updates).to eq(%w[small next])
      end

      it 'ignores an oversized snapshot with an invalid client id', :aggregate_failures do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES', 10)
        perform :receive, message('sync', 'one')
        perform :receive, message('sync', 'two')
        token = transmissions.last['token']
        oversized = 'a' * (Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES + 1)

        perform :receive, message('snapshot', oversized).merge('token' => token, 'clientId' => 'invalid')

        expect(transmissions).not_to include(hash_including('type' => 'payload_too_large'))
        expect(store_for(page).updates).to eq(%w[one two])
      end

      it 'relays the snapshot to peers as a sync' do
        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')
        token = transmissions.last['token']

        expect { perform :receive, message('snapshot', 'a-snapshot').merge('token' => token) }
          .to have_broadcasted_to(stream_name)
          .with('type' => 'sync', 'payload' => 'a-snapshot', 'clientId' => 1)
      end

      it 'removes the compaction token before passing the snapshot to broadcast' do
        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')
        token = transmissions.last['token']

        expect(subscription).to receive(:broadcast)
          .with({ 'type' => 'sync', 'payload' => 'a-snapshot', 'clientId' => 1 })
          .and_call_original

        perform :receive, message('snapshot', 'a-snapshot').merge('token' => token)
      end

      it 'does not relay a snapshot the store rejected' do
        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')

        expect { perform :receive, message('snapshot', 'a-snapshot').merge('token' => 'forged') }
          .not_to have_broadcasted_to(stream_name)
      end

      it 'does not acknowledge a rejected snapshot' do
        perform :receive, message('snapshot', 'a-snapshot').merge('token' => 'forged', 'messageId' => 13)

        expect(transmissions).not_to include(hash_including('type' => 'ack'))
      end

      it 'ignores a snapshot from a client that was not asked to compact' do
        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')

        perform :receive, message('snapshot', 'a-snapshot').merge('token' => 'forged')

        expect(store_for(page).updates).to eq(%w[first second])
      end

      it 'ignores a snapshot with no token' do
        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')

        perform :receive, message('snapshot', 'a-snapshot')

        expect(store_for(page).updates).to eq(%w[first second])
      end

      [{ 'a' => 'b' }, 1, %w[a b]].each do |bad|
        it "ignores a snapshot carrying a #{bad.class} token" do
          perform :receive, message('sync', 'first')
          perform :receive, message('sync', 'second')

          perform :receive, message('snapshot', 'a-snapshot').merge('token' => bad)

          expect(store_for(page).updates).to eq(%w[first second])
        end
      end
    end

    context 'when the log is at its ceiling' do
      before do
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::COMPACTION_THRESHOLD', 2)
        stub_const('Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_LENGTH', 2)

        perform :receive, message('sync', 'first')
        perform :receive, message('sync', 'second')
      end

      it 'tells the sender the document is full' do
        perform :receive, message('sync', 'third')

        expect(transmissions.last).to eq({ 'type' => 'document_full' })
      end

      it 'identifies the rejected update when reporting a full document' do
        perform :receive, message('sync', 'third').merge('messageId' => 14)

        expect(transmissions.last).to eq({ 'type' => 'document_full', 'messageId' => 14 })
      end

      it 'does not echo a non-integer message ID when reporting a full document' do
        perform :receive, message('sync', 'third').merge('messageId' => { 'untrusted' => 'value' })

        expect(transmissions.last).to eq({ 'type' => 'document_full' })
      end

      it 'does not acknowledge the rejected update' do
        perform :receive, message('sync', 'third').merge('messageId' => 14, 'saveId' => 'rejected-save')

        expect(transmissions).not_to include(hash_including('type' => 'ack'))
        expect(subscription.send(:store).claim_save(session_id: transmissions.first.fetch('sessionId'),
          save_id: 'another-save', user_id: developer.id)).to be(true)
      end

      it 'does not relay the rejected update' do
        expect { perform :receive, message('sync', 'third') }
          .not_to have_broadcasted_to(stream_name)
      end

      it 'does not store the rejected update' do
        perform :receive, message('sync', 'third')

        expect(store_for(page).updates).to eq(%w[first second])
      end

      context 'and the compactor never delivered a snapshot' do
        before do
          Gitlab::Redis::SharedState.with do |redis|
            redis.del("collaborative_editing:{#{document_key}}:compaction")
          end
        end

        it 'asks the sender to compact as well as reporting it full', :aggregate_failures do
          perform :receive, message('sync', 'third')

          types = transmissions.map { |t| t['type'] }

          expect(types).to include('document_full')
          expect(transmissions.last).to include('type' => 'request_snapshot')
          expect(transmissions.last['token']).to be_present
        end

        it 'accepts updates again once that snapshot arrives', :aggregate_failures do
          perform :receive, message('sync', 'third')
          token = transmissions.last['token']

          perform :receive, message('snapshot', 'a-snapshot').merge('token' => token)
          perform :receive, message('sync', 'fourth')

          expect(store_for(page).updates).to eq(%w[a-snapshot fourth])
        end
      end
    end

    context 'when the user-wide rate limit is exceeded', :freeze_time, :clean_gitlab_redis_rate_limiting do
      before do
        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:throttled?)
          .with(:collaborative_editing_update_by_user, scope: { user: developer })
          .and_return(true)
      end

      it 'stops relaying updates' do
        expect { perform :receive, message('sync', 'an-update') }
          .not_to have_broadcasted_to(stream_name)
      end

      it 'does not persist the update' do
        perform :receive, message('sync', 'an-update')

        expect(store_for(page).updates).to be_empty
      end

      it 'does not acknowledge the dropped update' do
        perform :receive, message('sync', 'an-update').merge('messageId' => 15)

        expect(transmissions).not_to include(hash_including('type' => 'ack'))
      end
    end

    it 'does not relay, store or acknowledge an update when the document rate limit is exceeded',
      :clean_gitlab_redis_rate_limiting, :aggregate_failures do
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update_by_user, scope: { user: developer })
        .and_call_original
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_bytes_by_user, scope: { user: developer }, cost: 'an-update'.bytesize)
        .and_call_original
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update, scope: { user: developer, document_key: document_key })
        .and_return(true)

      expect { perform :receive, message('sync', 'an-update').merge('messageId' => 15) }
        .not_to have_broadcasted_to(stream_name)
      expect(store_for(page).updates).to be_empty
      expect(transmissions).not_to include(hash_including('type' => 'ack'))
    end

    it 'counts updates from every subscription against one limit',
      :clean_gitlab_redis_rate_limiting do
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update_by_user, scope: { user: developer })
        .and_call_original
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_bytes_by_user, scope: { user: developer }, cost: anything)
        .and_call_original

      expect(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update, scope: { user: developer, document_key: document_key })
        .twice
        .and_call_original

      perform :receive, message('sync', 'first')

      subscribe(subscribe_params)
      perform :receive, message('sync', 'second')
    end

    it 'applies a user-wide limit across different wiki pages',
      :clean_gitlab_redis_rate_limiting do
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update, scope: { user: developer, document_key: anything })
        .and_call_original
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_bytes_by_user, scope: { user: developer }, cost: anything)
        .and_call_original

      expect(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update_by_user, scope: { user: developer })
        .twice
        .and_call_original

      perform :receive, message('sync', 'first')

      other_page = create(:wiki_page, wiki: project.wiki, content: 'Other')
      subscribe(container_full_path: project.full_path, slug: other_page.slug,
        last_commit_sha: other_page.last_commit_sha)
      perform :receive, message('sync', 'second')
    end

    it 'rejects messages when the user-wide limit is exceeded',
      :clean_gitlab_redis_rate_limiting do
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update_by_user, scope: { user: developer })
        .and_return(true)

      expect { perform :receive, message('sync', 'an-update') }
        .not_to have_broadcasted_to(stream_name)
      expect(store_for(page).updates).to be_empty
    end

    it 'charges the payload size to the user-wide byte budget', :clean_gitlab_redis_rate_limiting do
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update_by_user, scope: { user: developer })
        .and_call_original
      allow(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_update, scope: { user: developer, document_key: document_key })
        .and_call_original
      expect(Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?)
        .with(:collaborative_editing_bytes_by_user, scope: { user: developer }, cost: 2)
        .and_call_original

      perform :receive, message('awareness', 'é')
    end

    it 'rejects an update when the user-wide byte budget is exhausted across pages',
      :clean_gitlab_redis_rate_limiting, :aggregate_failures do
      perform :receive, message('sync', 'a')
      Gitlab::ApplicationRateLimiter.throttled?(
        :collaborative_editing_bytes_by_user, scope: { user: developer }, cost: 64.megabytes - 1
      )

      other_page = create(:wiki_page, wiki: project.wiki, content: 'Other')
      subscribe(container_full_path: project.full_path, slug: other_page.slug,
        last_commit_sha: other_page.last_commit_sha)
      other_stream_name = "collaborative_editing:wiki:Project:#{project.id}:#{CGI.escape(other_page.slug)}:" \
        "#{store_for(other_page).open(version: other_page.last_commit_sha).session_id}"

      expect { perform :receive, message('sync', 'an-update').merge('messageId' => 15) }
        .not_to have_broadcasted_to(other_stream_name)
      expect(store_for(other_page).updates).to be_empty
      expect(transmissions).not_to include(hash_including('type' => 'ack'))
    end
  end

  def message(type, payload)
    { 'type' => type, 'payload' => payload, 'clientId' => 1,
      'sessionId' => transmissions.reverse_each.find { |entry| entry['type'] == 'init' }&.fetch('sessionId') }
  end

  def subscribe(parameters = {}, initialise: true, **keyword_parameters)
    parameters = parameters.merge(keyword_parameters)
    client_version = parameters.delete(:last_commit_sha) || page.last_commit_sha
    super(parameters)
    return unless initialise && subscription.send(:store)

    perform :initialize_session, { version: client_version }
    deliver_readiness
  end

  def deliver_readiness
    subscription.send(:receive_stream_message,
      { 'type' => 'session_ready', 'token' => subscription.instance_variable_get(:@readiness_token) })
  end

  def revalidate
    subscription.send(:revalidate_access)
  end

  def fail_next_page_lookup(lookup_method)
    allow(Wiki).to receive(:for_container).and_wrap_original do |original, *args|
      original.call(*args).tap do |wiki|
        allow(wiki.repository).to receive(lookup_method).and_raise(Gitlab::Git::CommandError, 'Temporary failure')
        allow(Wiki).to receive(:for_container).and_call_original
      end
    end
  end

  def store_for(wiki_page)
    Gitlab::CollaborativeEditing::DocumentStore.new(
      "wiki:Project:#{wiki_page.wiki.container.id}:#{CGI.escape(wiki_page.slug)}"
    ).tap { |store| store.open(version: wiki_page.last_commit_sha) }
  end
end
