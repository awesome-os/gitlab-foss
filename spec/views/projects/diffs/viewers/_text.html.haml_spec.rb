# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/diffs/viewers/_text.html.haml', feature_category: :source_code_management do
  include DiffHelper

  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Repository functionality requires real database objects
  let_it_be(:project) { create(:project, :repository) }
  # rubocop:enable RSpec/FactoryBot/AvoidCreate
  let(:repository) { project.repository }
  let(:commit) { project.commit }
  let(:diff_file) { commit.diffs.diff_files.first }
  let(:viewer) { diff_file.simple_viewer }

  context 'when diff contains only whitespace changes' do
    before do
      allow(diff_file).to receive_messages(whitespace_only?: true, diffable_text?: true)
    end

    it 'shows whitespace-only message' do
      render partial: 'projects/diffs/viewers/text', locals: { viewer: viewer }

      expect(rendered).to have_content('File changed. Contains only whitespace changes.')
    end
  end

  context 'when diff contains regular changes' do
    before do
      allow(diff_file).to receive(:whitespace_only?).and_return(false)
    end

    it 'renders the normal diff view' do
      render partial: 'projects/diffs/viewers/text', locals: { viewer: viewer }

      expect(rendered).not_to have_content('File changed. Contains only whitespace changes.')
    end
  end
end
