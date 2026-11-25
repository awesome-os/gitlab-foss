# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wikis::CollaborativeUpdateService, :clean_gitlab_redis_shared_state, feature_category: :wiki do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :wiki_repo, developers: user) }
  let(:page) { create(:wiki_page, wiki: project.wiki, content: 'Original') }
  let(:version) { page.last_commit_sha }
  let(:store) do
    Gitlab::CollaborativeEditing::DocumentStore.new(
      Gitlab::CollaborativeEditing::DocumentStore.document_key(project, page.slug))
  end

  let(:session) { store.open(version: version) }
  let(:marker) { { session_id: session.session_id, save_id: 'save', user_id: user.id } }
  let(:params) { { content: 'Updated', last_commit_sha: version } }

  subject(:save) do
    described_class.new(container: project, current_user: user, params: params)
      .execute(page, **marker.except(:user_id))
  end

  before do
    allow(ActionCable.server).to receive(:broadcast)
    store.append('accepted', session_id: session.session_id)
    store.claim_save(**marker)
  end

  it 'advances only this write and preserves the generation and log', :aggregate_failures do
    expect(save).to be_success
    expect(ActionCable.server).to have_received(:broadcast).with(store.stream_name(session.session_id),
      hash_including(type: 'version', previousVersion: version, saveId: 'save'))

    expect(store.read_session(session_id: session.session_id)).to eq([['accepted'], page.saved_commit_sha])
    expect(store.open(version: page.saved_commit_sha).session_id).to eq(session.session_id)
  end

  context 'without content changes' do
    let(:params) { super().merge(content: 'Original') }

    it 'keeps the last page-changing revision healthy', :aggregate_failures do
      expect(save).to be_success
      written = page.saved_commit_sha
      bound = project.wiki.repository.last_commit_for_path(written, page.path)&.sha
      expect(written).not_to eq(version)
      expect(bound).to eq(version)
      expect(store.touch(session_id: session.session_id, version: bound)).to be(true)
      expect(ActionCable.server).not_to have_received(:broadcast)
    end
  end

  { 'cannot be resolved' => -> {}, 'cannot be looked up' => -> { raise Gitlab::Git::CommandError } }
    .each do |outcome, lookup|
    it "releases without advancing when the written page revision #{outcome}", :aggregate_failures do
      allow(page.wiki.repository).to receive(:last_commit_for_path).and_wrap_original do |original, sha, *args|
        sha == page.saved_commit_sha ? lookup.call : original.call(sha, *args)
      end

      expect(save).to be_success
      expect(project.wiki.find_page(page.slug).content).to eq('Updated')
      expect(ActionCable.server).not_to have_received(:broadcast)
      expect(store.read_session(session_id: session.session_id).last).to eq(version)
      expect(store.claim_save(**marker)).to be(true)
    end
  end

  [{ title: 'renamed' }, { format: :asciidoc }, { front_matter: { title: 'Metadata' } }].each do |change|
    context "with #{change.each_key.first} changed" do
      let(:params) { super().merge(change) }

      it 'saves normally but releases without advancing', :aggregate_failures do
        expect(save).to be_success
        expect(ActionCable.server).not_to have_received(:broadcast)
        expect(store.read_session(session_id: session.session_id).last).to eq(version)
        expect(store.claim_save(**marker)).to be(true)
      end
    end
  end

  context 'with a conflicting write' do
    let(:params) { super().merge(last_commit_sha: 'stale') }

    it 'releases the marker after failure', :aggregate_failures do
      expect(save).to be_error
      expect(store.claim_save(**marker)).to be(true)
    end
  end

  it 'falls back to an ordinary update without a matching marker', :aggregate_failures do
    store.release_save(**marker)

    expect(save).to be_success
    expect(ActionCable.server).not_to have_received(:broadcast)
    expect(store.read_session(session_id: session.session_id).last).to eq(version)
  end

  it 'does not advance ordinary updates used by the API', :aggregate_failures do
    expect(WikiPages::UpdateService.new(container: project, current_user: user,
      params: params).execute(page)).to be_success
    expect(store.read_session(session_id: session.session_id).last).to eq(version)
  end

  it 'keeps a marker owned by another user during fallback', :aggregate_failures do
    store.release_save(**marker)
    store.claim_save(**marker.merge(user_id: user.id + 1))

    expect(save).to be_success
    expect(store.confirm_save(**marker.merge(user_id: user.id + 1), version: version)).to be(true)
    expect(ActionCable.server).not_to have_received(:broadcast)
  end

  it 'releases without advancing when an update hook raises after the write', :aggregate_failures do
    allow_next_instance_of(WikiPages::UpdateService) do |service|
      allow(service).to receive(:execute_hooks).and_raise(StandardError, 'Hook failed')
    end

    expect { expect(save).to be_success }.to raise_error(StandardError, 'Hook failed')
    expect(store.read_session(session_id: session.session_id).last).to eq(version)
    expect(store.claim_save(**marker)).to be(true)
  end
end
