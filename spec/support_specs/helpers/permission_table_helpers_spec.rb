# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PermissionTableHelpers, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  include described_class

  def permission_table
    :public  | :enabled  | :admin    | true | 1
    :private | :enabled  | :guest    | nil  | 0
    :public  | :enabled  | :reporter | nil  | 1
    :public  | :disabled | :reporter | nil  | 0
  end

  describe '#access_cases_by_setting' do
    it 'groups rows by every column but the last three, in order' do
      expect(access_cases_by_setting(permission_table)).to eq([
        [:public, :enabled, [[:admin, true, 1], [:reporter, nil, 1]]],
        [:private, :enabled, [[:guest, nil, 0]]],
        [:public, :disabled, [[:reporter, nil, 0]]]
      ])
    end

    it 'turns every row into an access case' do
      table = permission_table

      rows = access_cases_by_setting(table).flat_map do |*setting, access_cases|
        access_cases.map { |access_case| [*setting, *access_case] }
      end

      expect(rows).to match_array(table.to_params)
    end
  end
end
