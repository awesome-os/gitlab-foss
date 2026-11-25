# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PolicyHelpers, type: :policy, feature_category: :permissions do
  # read_build_report_results is enabled by `can?(:read_build) & can?(:read_pipeline)`.
  subject { ProjectPolicy.new(nil, build_stubbed(:project, :public)) }

  describe '#stub_permissions' do
    it 'decides the rules that check the stubbed permissions' do
      stub_permissions(read_build: true, read_pipeline: true)

      expect_allowed(:read_build_report_results)
    end

    it 'keeps permissions stubbed by an earlier call' do
      stub_permissions(read_build: false)
      stub_permissions(read_pipeline: true)

      expect_disallowed(:read_build_report_results)
    end

    it 'replaces results computed before the stub' do
      stub_permissions(read_build: true, read_pipeline: true)
      expect_allowed(:read_build_report_results)

      stub_permissions(read_pipeline: false)

      expect_disallowed(:read_build_report_results)
    end

    it 'raises for a permission the policy does not define' do
      expect { stub_permissions(read_cdoe: false) }
        .to raise_error(ArgumentError, 'ProjectPolicy does not define :read_cdoe')
    end

    # DeclarativePolicy copies the rules of :read_thing into a single
    # `can?(:read_thing)` rule when they are all enables, so `allowed?` is never called.
    context 'when the rule is a single can? check on a permission with only enable rules' do
      # The subject is whether :read_thing is granted.
      let(:policy_class) do
        Class.new(DeclarativePolicy::Base) do
          condition(:granted) { @subject }
          rule { granted }.enable :read_thing
          rule { can?(:read_thing) }.enable :read_other_thing
        end
      end

      subject { policy_class.new(nil, granted) }

      context 'when the permission is granted' do
        let(:granted) { true }

        it 'denies the rule when the permission is stubbed to false' do
          stub_permissions(read_thing: false)

          expect_disallowed(:read_other_thing)
        end
      end

      context 'when the permission is not granted' do
        let(:granted) { false }

        it 'allows the rule when the permission is stubbed to true' do
          stub_permissions(read_thing: true)

          expect_allowed(:read_other_thing)
        end
      end
    end
  end
end
