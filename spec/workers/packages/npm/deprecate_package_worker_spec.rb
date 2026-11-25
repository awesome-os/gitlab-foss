# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Npm::DeprecatePackageWorker, feature_category: :package_registry do
  describe '#perform' do
    let_it_be(:project) { create(:project) }
    let(:params) { { 'package_name' => 'package_name', 'versions' => {} } }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [project.id, params] }

      it 'does not call the deprecation service' do
        expect(::Packages::Npm::DeprecatePackageService).not_to receive(:new)

        described_class.new.perform(*job_args)
      end
    end
  end
end
