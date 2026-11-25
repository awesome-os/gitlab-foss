# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNoteHelper, feature_category: :code_review_workflow do
  describe '.system_note_icon_name' do
    subject(:system_note_icon_name) { helper.system_note_icon_name(note) }

    context 'for an requested changes note' do
      let_it_be(:note) { build_stubbed(:note, :system) }
      let_it_be(:system_note_metadata) { build_stubbed(:system_note_metadata, note: note, action: :requested_changes) }

      it 'returns the iteration icon name' do
        expect(system_note_icon_name).to eq('error')
      end
    end

    context 'for a merge request note that aborted the automatic merge' do
      where(note_action: %w[merge auto_merge_aborted_target_branch_updated auto_merge_aborted_target_branch_merged])

      with_them do
        let(:note) do
          build_stubbed(:note_on_merge_request, :system,
            system_note_metadata: build_stubbed(:system_note_metadata, action: note_action))
        end

        it 'returns the merge request system note icon name' do
          expect(helper.system_note_icon_name(note)).to eq('mr-system-note-empty')
        end
      end
    end
  end
end
