# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'DatabaseCleaner deletion with session_replication_role', :delete, feature_category: :database do
  let(:connection) { ApplicationRecord.connection }

  it 'deletes rows referenced by foreign keys without toggling triggers', :aggregate_failures do
    create(:personal_access_token)

    recorder = ActiveRecord::QueryRecorder.new { delete_from_all_tables!(except: deletion_except_tables) }

    expect(User.count).to eq(0)
    expect(PersonalAccessToken.count).to eq(0)
    expect(recorder.log).to include(a_string_matching(/SET LOCAL session_replication_role = replica/))
    expect(recorder.log).not_to include(a_string_matching(/ALTER TABLE/i))
  end

  it 'restores the origin role after cleaning' do
    delete_from_all_tables!(except: deletion_except_tables)

    expect(connection.select_value('SHOW session_replication_role')).to eq('origin')
  end
end
