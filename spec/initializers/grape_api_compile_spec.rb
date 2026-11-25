# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'grape_api_compile', feature_category: :api do
  subject(:run_initializer) { load Rails.root.join('config/initializers/grape_api_compile.rb') }

  let(:puma) { true }
  let(:eager_load) { true }

  before do
    allow(Gitlab::Runtime).to receive(:puma?).and_return(puma)
    allow(Rails.application.config).to receive(:eager_load).and_return(eager_load)
  end

  it 'compiles the API before forking Puma workers' do
    expect(Gitlab::Cluster::LifecycleEvents).to receive(:on_before_fork).and_yield
    expect(API::API).to receive(:compile!)

    run_initializer
  end

  context 'when not running in Puma' do
    let(:puma) { false }

    it 'does not register a hook' do
      expect(Gitlab::Cluster::LifecycleEvents).not_to receive(:on_before_fork)

      run_initializer
    end
  end

  context 'when classes are not eager loaded' do
    let(:eager_load) { false }

    it 'does not register a hook' do
      expect(Gitlab::Cluster::LifecycleEvents).not_to receive(:on_before_fork)

      run_initializer
    end
  end
end
