# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Limit::ParticipantFieldsRateLimit, feature_category: :team_planning do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  def field_for(type_name, field_name)
    GitlabSchema.types[type_name].fields[field_name]
  end

  describe 'the guarded fields' do
    where(:type_name, :field_name) do
      'Issue'                        | 'participants'
      'Issue'                        | 'subscribed'
      'MergeRequest'                 | 'participants'
      'MergeRequest'                 | 'subscribed'
      'WorkItemWidgetParticipants'   | 'participants'
      'WorkItemWidgetNotifications'  | 'subscribed'
    end

    with_them do
      it 'use the shared rate limit' do
        expect(field_for(type_name, field_name).extensions).to include(an_instance_of(described_class))
      end
    end

    context 'with EE types', if: Gitlab.ee? do
      where(:field_name) { %w[participants subscribed] }

      with_them do
        it 'use the shared rate limit' do
          expect(field_for('Epic', field_name).extensions).to include(an_instance_of(described_class))
        end
      end
    end
  end

  describe 'resolving a guarded field' do
    let(:user) { build_stubbed(:user) }
    let(:owner) { fresh_object_type }
    let(:query) { GraphQL::Query.new(GitlabSchema, context: { current_user: user }) }
    let(:field) do
      ::Types::BaseField.new(name: 'value', type: GraphQL::Types::String, null: true, owner: owner) do
        extension(::Gitlab::Graphql::Limit::ParticipantFieldsRateLimit)
      end
    end

    before do
      stub_const("#{described_class}::THRESHOLD", 1)
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    it 'checks the graphql_participant_fields key past the threshold' do
      2.times { resolve_field(field, { value: 'foo' }, object_type: owner, query: query) }

      expect(::Gitlab::ApplicationRateLimiter)
        .to have_received(:throttled?).with(:graphql_participant_fields, scope: { user: user })
    end
  end
end
