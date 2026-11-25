# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Diff::ModeChange, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  describe '#type' do
    where(:old_mode, :new_mode, :type) do
      nil      | '100644' | nil
      '100644' | nil      | nil
      '100644' | '100644' | nil
      '0'      | '100644' | nil
      '100644' | '0'      | nil
      '0'      | '120000' | nil
      '0'      | '160000' | nil
      '160000' | '0'      | nil
      '100644' | '100755' | :executable_gained
      '0'      | '100755' | :executable_gained
      '100755' | '100644' | :executable_lost
      '100755' | '0'      | :executable_lost
      '100644' | '120000' | :other
      '100664' | '100644' | :other
    end

    with_them do
      it { expect(described_class.new(old_mode, new_mode).type).to eq(type) }
    end
  end

  describe '#new_file? and #deleted_file?' do
    it 'tells a missing side apart', :aggregate_failures do
      expect(described_class.new('0', '100755')).to be_new_file
      expect(described_class.new('0', '100755')).not_to be_deleted_file
      expect(described_class.new('100755', '0')).to be_deleted_file
      expect(described_class.new('100644', '100755')).not_to be_new_file
    end
  end
end
