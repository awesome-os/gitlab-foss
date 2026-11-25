# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Routing::ConstraintLookup, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project) }

  let(:request) { ActionDispatch::Request.new(Rack::MockRequest.env_for('/')) }
  let(:full_path) { project.full_path }

  describe '.store and .fetch' do
    before do
      described_class.store(request, Project, full_path, true, project)
    end

    it 'returns the stored routable for the same class, path and follow_redirects' do
      expect(described_class.fetch(request, Project, full_path, true)).to eq(project)
    end

    it 'returns nil for a different class' do
      expect(described_class.fetch(request, Group, full_path, true)).to be_nil
    end

    it 'returns nil for a different path' do
      expect(described_class.fetch(request, Project, 'other/path', true)).to be_nil
    end

    it 'returns nil for a different follow_redirects' do
      expect(described_class.fetch(request, Project, full_path, false)).to be_nil
    end

    it 'returns nil for a relation without loading it' do
      relation = Project.all

      expect(relation).not_to receive(:load)
      expect(described_class.fetch(request, relation, full_path, true)).to be_nil
    end

    it 'does not leak into another request' do
      other_request = ActionDispatch::Request.new(Rack::MockRequest.env_for('/'))

      expect(described_class.fetch(other_request, Project, full_path, true)).to be_nil
    end
  end

  describe '.fetch' do
    it 'returns nil when nothing was stored' do
      expect(described_class.fetch(request, Project, full_path, true)).to be_nil
    end
  end
end
