# frozen_string_literal: true

module Ci
  module Catalog
    module BundledResources
      module Eligibility
        def self.eligible?(project)
          return false unless project&.catalog_resource&.gitlab_maintained?

          Ability.allowed?(nil, :download_code, project)
        end
      end
    end
  end
end
