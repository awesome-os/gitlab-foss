# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Search::RecentIssues, feature_category: :global_search do
  let(:parent_type) { :project }

  def create_item(content:, parent:)
    create(:issue, title: content, project: parent)
  end

  it_behaves_like 'search recent items'
end
