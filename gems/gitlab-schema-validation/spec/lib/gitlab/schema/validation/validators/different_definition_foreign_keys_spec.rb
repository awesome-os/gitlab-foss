# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Schema::Validation::Validators::DifferentDefinitionForeignKeys, feature_category: :database do
  include_examples 'foreign key validators', described_class, ['public.issues.wrong_definition_fk']
end
