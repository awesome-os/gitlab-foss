# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WikiPagePolicy, feature_category: :wiki do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:wiki_page) { build(:wiki_page, container: project) }
  let(:permissions) do
    %i[read_wiki_page read_note create_note update_subscription award_emoji mark_note_as_internal]
  end

  subject(:policy) { described_class.new(user, wiki_page) }

  it { expect(described_class.new(nil, wiki_page)).to delegate_to(ProjectPolicy) }

  it { expect_allowed(*permissions) }

  context 'when the user cannot read the wiki' do
    before do
      stub_permissions(read_wiki: false)
    end

    it { expect_disallowed(*permissions) }
  end
end
