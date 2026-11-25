# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::MobilePush::Payload, feature_category: :notifications do
  let_it_be(:user) { create(:user) }
  let_it_be(:author) { create(:user, name: 'Jane Doe') }
  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue, project: project, title: 'Fix the frobnicator') }

  let(:todo) { create(:todo, user: user, author: author, project: project, target: issue) }

  subject(:payload) { described_class.new(todo) }

  describe '#title' do
    it 'uses the target title' do
      expect(payload.title).to eq('Fix the frobnicator')
    end

    context 'when the target has no title' do
      before do
        allow(issue).to receive(:title).and_return(nil)
        allow(todo).to receive(:target).and_return(issue)
      end

      it 'falls back to the target reference' do
        expect(payload.title).to eq("##{issue.iid}")
      end
    end
  end

  describe '#subtitle' do
    it 'combines the full path and the reference' do
      expect(payload.subtitle).to eq("#{project.full_path} · ##{issue.iid}")
    end
  end

  describe '#body' do
    it 'combines the author name and the action phrase' do
      expect(payload.body).to eq('Jane Doe assigned you.')
    end

    context 'when the action phrase is a standalone sentence' do
      let(:todo) { create(:todo, :build_failed, user: user, author: author, project: project) }

      it 'omits the author, mirroring the app' do
        expect(payload.body).to eq('The pipeline failed.')
      end
    end

    context 'when the action has no curated phrase' do
      before do
        allow(todo).to receive(:action_name).and_return(:frobnicated_widget)
      end

      it 'humanizes the action name like the app fallback' do
        expect(payload.body).to eq('Jane Doe frobnicated widget.')
      end
    end

    context 'when a review was submitted' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }

      it 'names an approval' do
        todo = create(:todo, :review_approved, user: user, author: author, project: project, target: merge_request)

        expect(described_class.new(todo).body).to eq('Jane Doe approved your merge request.')
      end

      it 'names a change request' do
        todo = create(:todo, :review_changes_requested, user: user, author: author, project: project,
          target: merge_request)

        expect(described_class.new(todo).body).to eq('Jane Doe requested changes to your merge request.')
      end

      it 'keeps the generic phrase for a plain review' do
        todo = create(:todo, :review_submitted, user: user, author: author, project: project, target: merge_request)

        expect(described_class.new(todo).body).to eq('Jane Doe reviewed your merge request.')
      end
    end
  end

  describe '#badge' do
    it 'is the pending to-do count of the recipient' do
      todo

      expect(payload.badge).to eq(1)
    end
  end

  describe '#thread_id' do
    it 'is the full path plus the reference' do
      expect(payload.thread_id).to eq("#{project.full_path}##{issue.iid}")
    end
  end

  describe '#collapse_id' do
    it 'is derived from the todo id' do
      expect(payload.collapse_id).to eq("todo-#{todo.id}")
    end
  end

  describe '#gitlab_data' do
    it 'carries the structured todo attributes' do
      expect(payload.gitlab_data).to eq(
        version: 1,
        type: 'todo',
        todo_id: todo.id,
        user_id: user.id,
        action: 'assigned',
        target_type: 'Issue',
        project_path: project.full_path,
        iid: issue.iid,
        target_url: Gitlab::UrlBuilder.build(issue),
        note_id: nil,
        created_at: todo.created_at.utc.iso8601(3),
        author_id: author.id,
        author_name: 'Jane Doe',
        author_username: author.username,
        author_avatar_url: author.avatar_url(only_path: false)
      )
    end

    it 'names who acted and when, so the app can pick the exact resource the todo was raised for' do
      data = payload.gitlab_data

      expect(Time.zone.parse(data[:created_at])).to be_within(0.001).of(todo.created_at)
      expect(data[:author_avatar_url]).to start_with('http')
    end

    context 'when the todo is attached to a note' do
      let_it_be(:note) { create(:note_on_issue, project: project, noteable: issue) }

      let(:todo) do
        create(:todo, :mentioned, user: user, author: author, project: project, target: issue, note: note)
      end

      it 'exposes the note id' do
        expect(payload.gitlab_data[:note_id]).to eq(note.id)
      end
    end

    context 'when the todo was raised by a submitted review' do
      let_it_be(:merge_request) { create(:merge_request) }

      let(:todo) do
        create(:todo, :review_submitted, user: user, author: author, project: merge_request.project,
          target: merge_request)
      end

      it 'names the review' do
        link = create(:todo_review_link, todo: todo)

        expect(payload.gitlab_data).to include(review_id: link.review_id)
      end

      it 'omits the review key when no review is tied to the todo' do
        expect(payload.gitlab_data.keys).not_to include(:review_id)
      end
    end
  end

  describe '#mutable_content?' do
    it 'is false in full mode' do
      expect(payload.mutable_content?).to be(false)
    end
  end

  describe 'id_only mode' do
    subject(:payload) { described_class.new(todo, mode: :id_only) }

    it 'is id_only' do
      expect(payload).to be_id_only
    end

    it 'carries no todo content in the alert fields' do
      expect(payload.title).to be_nil
      expect(payload.subtitle).to be_nil
      expect(payload.thread_id).to be_nil
      expect(payload.body).to eq('You have a new to-do')
    end

    it 'keeps the badge' do
      todo

      expect(payload.badge).to eq(1)
    end

    it 'keeps the collapse id' do
      expect(payload.collapse_id).to eq("todo-#{todo.id}")
    end

    it 'requests mutable content so the app can render on-device' do
      expect(payload.mutable_content?).to be(true)
    end

    it 'restricts the gitlab dict to identifiers' do
      expect(payload.gitlab_data).to eq(
        version: 1,
        type: 'todo',
        todo_id: todo.id,
        user_id: user.id
      )
    end

    context 'when the todo was raised by a submitted review' do
      let_it_be(:merge_request) { create(:merge_request) }

      let(:todo) do
        create(:todo, :review_submitted, user: user, author: author, project: merge_request.project,
          target: merge_request)
      end

      it 'still restricts the gitlab dict to identifiers' do
        create(:todo_review_link, todo: todo)

        expect(payload.gitlab_data.keys).to contain_exactly(:version, :type, :todo_id, :user_id)
      end
    end
  end

  describe 'encrypted mode' do
    subject(:payload) { described_class.new(todo, mode: :encrypted) }

    let(:key) { SecureRandom.random_bytes(32) }
    let(:subscription) do
      build(:mobile_device_push_subscription, user: user, content_key: Base64.strict_encode64(key))
    end

    it 'is encrypted and not id_only' do
      expect(payload).to be_encrypted
      expect(payload).not_to be_id_only
    end

    it 'shows the generic alert and no thread id before the extension runs' do
      expect(payload.title).to be_nil
      expect(payload.subtitle).to be_nil
      expect(payload.body).to eq(described_class::GENERIC_BODY)
      expect(payload.thread_id).to be_nil
    end

    it 'requests mutable content so the extension can open the envelope' do
      expect(payload.mutable_content?).to be(true)
    end

    it 'carries identifiers only in the shared gitlab_data' do
      expect(payload.gitlab_data).to eq(version: 1, type: 'todo', todo_id: todo.id, user_id: user.id)
    end

    describe '#gitlab_data_for' do
      it 'seals the full content for the subscription so only its device opens it' do
        data = payload.gitlab_data_for(subscription)

        expect(data).to include(version: 1, type: 'todo')
        expect(data).not_to have_key(:todo_id)
        envelope = data[:content]
        expect(envelope).to include(alg: 'A256GCM', v: 2)
        expect(envelope[:iat]).to be_within(5).of(Time.current.to_i)

        plaintext = open_envelope(envelope, key: key, device_token: subscription.device_token)
        expect(plaintext['title']).to eq('Fix the frobnicator')
        expect(plaintext['subtitle']).to eq("#{project.full_path} · ##{issue.iid}")
        expect(plaintext['body']).to eq('Jane Doe assigned you.')
        expect(plaintext['thread_id']).to eq("#{project.full_path}##{issue.iid}")
        expect(plaintext['gitlab']).to include(
          'todo_id' => todo.id, 'action' => 'assigned', 'project_path' => project.full_path
        )
      end

      it 'does not open under another device token' do
        envelope = payload.gitlab_data_for(subscription)[:content]

        expect { open_envelope(envelope, key: key, device_token: SecureRandom.hex(32)) }
          .to raise_error(OpenSSL::Cipher::CipherError)
      end

      it 'does not open under another key' do
        envelope = payload.gitlab_data_for(subscription)[:content]

        expect { open_envelope(envelope, key: SecureRandom.random_bytes(32), device_token: subscription.device_token) }
          .to raise_error(OpenSSL::Cipher::CipherError)
      end

      it 'caps long text by bytes to stay under the APNs payload limit' do
        allow(issue).to receive(:title).and_return('x' * 1_000)
        allow(todo).to receive(:target).and_return(issue)

        plaintext = open_envelope(payload.gitlab_data_for(subscription)[:content],
          key: key, device_token: subscription.device_token)

        expect(plaintext['title'].bytesize).to be <= described_class::ENCRYPTED_TEXT_BYTES
        expect(payload.gitlab_data_for(subscription).to_json.bytesize).to be <= described_class::ENCRYPTED_DATA_BYTES
      end

      it 'caps multi-byte text by bytes without splitting a character' do
        allow(issue).to receive(:title).and_return('🚀' * 255)
        allow(author).to receive(:name).and_return('日本語' * 85)
        allow(todo).to receive(:target).and_return(issue)

        plaintext = open_envelope(payload.gitlab_data_for(subscription)[:content],
          key: key, device_token: subscription.device_token)

        expect(plaintext['title'].bytesize).to be <= described_class::ENCRYPTED_TEXT_BYTES
        expect(plaintext['title']).to be_valid_encoding
        expect(plaintext['title']).to start_with('🚀')
        expect(plaintext['body'].bytesize).to be <= described_class::ENCRYPTED_TEXT_BYTES
        expect(plaintext['body']).to start_with('日本語')
        expect(payload.gitlab_data_for(subscription).to_json.bytesize).to be <= described_class::ENCRYPTED_DATA_BYTES
      end

      it 'falls back to identifiers when the untruncated fields outgrow the budget' do
        allow(project).to receive(:full_path).and_return("group/#{'p' * 4_000}")
        allow(todo).to receive(:resource_parent).and_return(project)

        expect(payload.gitlab_data_for(subscription)).to eq(
          version: 1, type: 'todo', todo_id: todo.id, user_id: user.id
        )
      end

      it 'falls back to identifiers when the stored key does not decode' do
        subscription.content_key = 'not-base64!'

        expect(payload.gitlab_data_for(subscription)).to eq(
          version: 1, type: 'todo', todo_id: todo.id, user_id: user.id
        )
      end
    end

    # @note Mirrors the app's notification extension: AES-256-GCM over
    #   nonce || ciphertext || tag with the version-2 additional data.
    def open_envelope(envelope, key:, device_token:)
      combined = Base64.strict_decode64(envelope[:ciphertext])
      cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
      cipher.key = key
      cipher.iv = combined[0, 12]
      cipher.auth_tag = combined[-16..]
      cipher.auth_data = Gitlab::MobilePush::EncryptedContent.additional_data(
        device_token: device_token, issued_at: envelope[:iat]
      )
      # OpenSSL::Cipher#update, not an ActiveRecord save.
      plaintext = cipher.update(combined[12...-16]) + cipher.final # rubocop:disable Rails/SaveBang -- OpenSSL
      Gitlab::Json::SafeParser.parse(plaintext)
    end
  end

  describe 'full mode #gitlab_data_for' do
    it 'is the shared gitlab_data' do
      subscription = build(:mobile_device_push_subscription, user: user)

      expect(payload.gitlab_data_for(subscription)).to eq(payload.gitlab_data)
    end
  end
end
