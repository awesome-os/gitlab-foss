# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::MarkdownCache::RefreshWorker, feature_category: :markdown do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, :with_namespace) }

  let(:cache_version) { Gitlab::MarkdownCache::CACHE_COMMONMARK_VERSION_SHIFTED }

  let(:note) do
    create(:note_on_issue, project: project, note: "hey @#{user.username}").tap do |note|
      note.update_columns(note_html: nil, cached_markdown_version: nil)
      IssueUserMention.where(note_id: note.id).delete_all
    end
  end

  let(:job_args) { [note.class.name, [note.id]] }

  subject(:perform) { described_class.new.perform(*job_args) }

  it_behaves_like 'an idempotent worker' do
    it 'persists the refreshed HTML and mentions' do
      perform_idempotent_work

      expect(note.reload.cached_markdown_version).to eq(cache_version)
      expect(note.note_html).to be_present
      expect(IssueUserMention.where(note_id: note.id).pick(:mentioned_users_ids)).to eq([user.id])
    end
  end

  it 'logs the record ids' do
    expect(described_class.loggable_arguments).to include(1)
  end

  context 'with several records' do
    let(:other_note) do
      create(:note_on_issue, project: project).tap do |note|
        note.update_columns(note_html: nil, cached_markdown_version: nil)
      end
    end

    let!(:job_args) { ['Note', [note.id, other_note.id]] }

    it 'refreshes each of them' do
      perform

      expect([note, other_note].map { |record| record.reload.cached_markdown_version })
        .to all(eq(cache_version))
    end

    it 'keeps reading from replicas after writing' do
      ::Gitlab::Database::LoadBalancing::SessionMap.clear_session

      perform

      session = ::Gitlab::Database::LoadBalancing::SessionMap.current(Note.load_balancer)
      expect(session).to be_performed_write
      expect(session).not_to be_using_primary
    end

    context 'when one of them fails to refresh' do
      before do
        allow(Banzai::Renderer).to receive(:cacheless_render_field).and_call_original
        allow(Banzai::Renderer).to receive(:cacheless_render_field)
          .with(an_object_having_attributes(id: note.id), :note, anything).and_raise(ArgumentError)
      end

      it 'refreshes the others, then raises' do
        expect { perform }.to raise_error(ArgumentError)

        expect(other_note.reload.cached_markdown_version).to eq(cache_version)
      end
    end

    context 'when several of them fail to refresh' do
      before do
        allow(Banzai::Renderer).to receive(:cacheless_render_field).and_raise(ArgumentError)
      end

      it 'raises the first error and tracks the others' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(an_instance_of(ArgumentError), class_name: 'Note', id: an_instance_of(Integer)).once

        expect { perform }.to raise_error(ArgumentError)
      end
    end
  end

  context 'with a single id, as enqueued before ids were batched' do
    let(:job_args) { [note.class.name, note.id] }

    it 'refreshes the record' do
      perform

      expect(note.reload.cached_markdown_version).to eq(cache_version)
    end
  end

  it 'does not defer on database health signals' do
    expect(described_class.defer_on_database_health_signal?).to be(false)
  end

  context 'when the record is already current' do
    before do
      note.refresh_markdown_cache!
    end

    it 'does not render it again' do
      expect(Banzai::Renderer).not_to receive(:cacheless_render_field)

      perform
    end
  end

  context 'when the record no longer exists' do
    let(:job_args) { ['Note', [non_existing_record_id]] }

    it 'does nothing' do
      expect { perform }.not_to raise_error
    end
  end

  context 'when the class does not exist' do
    let(:job_args) { ['NoSuchMarkdownModel', [non_existing_record_id]] }

    it 'does nothing' do
      expect { perform }.not_to raise_error
    end
  end
end
