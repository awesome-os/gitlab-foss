# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DesignManagement'] do
  it { expect(described_class).to have_graphql_fields(:version, :design_at_version) }

  describe 'fine-grained token authorization' do
    it 'checks a fine-grained token on every field' do
      unchecked_fields = described_class.fields.values.reject do |field|
        granular_directive?(field) || checks_fine_grained_tokens?(field.type.unwrap)
      end

      expect(unchecked_fields.map(&:graphql_name)).to be_empty
    end

    def granular_directive?(member)
      member.directives.any?(::Directives::Authz::GranularScope)
    end

    def checks_fine_grained_tokens?(type)
      directives = type.directives.grep(::Directives::Authz::GranularScope)

      directives.any? && directives.none? { |directive| directive.arguments[:skip_reason].present? }
    end
  end
end
