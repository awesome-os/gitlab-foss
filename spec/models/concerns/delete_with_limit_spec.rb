# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DeleteWithLimit do
  describe '.delete_with_limit' do
    let_it_be(:project) { create(:project) }

    it 'deletes a limited amount of rows' do
      create_list(:event, 4, project: project, author: project.creator)

      expect do
        Event.delete_with_limit(2)
      end.to change { Event.count }.by(-2)
    end
  end
end
