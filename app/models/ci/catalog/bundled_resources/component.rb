# frozen_string_literal: true

module Ci
  module Catalog
    module BundledResources
      class Component < ::ApplicationRecord
        include FileStoreMounter
        include ShaAttribute

        self.table_name = 'catalog_bundled_resource_components'

        NAME_REGEX = /\A#{::Ci::Catalog::ComponentsProject::NAME_PATTERN}\z/

        mount_file_store_uploader Ci::Catalog::BundledResources::ComponentUploader
        sha256_attribute :file_sha256

        belongs_to :bundled_resource, class_name: 'Ci::Catalog::BundledResource',
          foreign_key: :catalog_bundled_resource_id, inverse_of: :components, optional: false
        belongs_to :version, class_name: 'Ci::Catalog::BundledResources::Version',
          foreign_key: :catalog_bundled_version_id, inverse_of: :components, optional: false

        validates :name, presence: true, length: { maximum: 255 },
          format: { with: NAME_REGEX },
          uniqueness: { scope: :catalog_bundled_version_id }
        scope :for_bundled_resources, ->(bundled_resource_ids) {
          where(catalog_bundled_resource_id: bundled_resource_ids)
        }
        scope :with_digest, -> { where.not(file_sha256: nil) }
        scope :ordered_by_id, -> { order(id: :asc) }
        scope :with_natural_key, -> { preload(:bundled_resource, :version) }

        validates :spec, json_schema: { filename: 'catalog_resource_component_spec', size_limit: 64.kilobytes }
      end
    end
  end
end
