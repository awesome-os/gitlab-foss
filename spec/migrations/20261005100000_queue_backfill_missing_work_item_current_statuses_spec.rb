# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe QueueBackfillMissingWorkItemCurrentStatuses, migration: :gitlab_main_org, feature_category: :team_planning do
  let!(:batched_migration) { described_class::MIGRATION }

  it 'does not schedule anything, the requeue does' do
    migrate!

    expect(batched_migration).not_to have_scheduled_batched_migration
  end
end
