# frozen_string_literal: true

module Packages
  module Nuget
    class Package < Packages::Package
      self.allow_legacy_sti_class = true

      # `deprecated` is npm-only, so excluding it keeps NuGet lookups on the
      # `status = ANY (ARRAY[0, 1])` partial index (idx_pkgs_project_id_lower_name_when_nuget_installable_version).
      INSTALLABLE_STATUSES = [:default, :hidden].freeze

      has_many :installable_nuget_package_files, -> {
        installable.with_nuget_format
      }, class_name: 'Packages::PackageFile', inverse_of: :package

      has_one :nuget_metadatum, inverse_of: :package, class_name: 'Packages::Nuget::Metadatum'
      has_many :nuget_symbols, inverse_of: :package, class_name: 'Packages::Nuget::Symbol'

      validates :name, format: { with: Gitlab::Regex.nuget_package_name_regex }
      validates :version, format: { with: Gitlab::Regex.nuget_version_regex }

      scope :with_nuget_version_or_normalized_version, ->(version, with_normalized: true) do
        relation = with_case_insensitive_version(version)

        return relation unless with_normalized

        relation
          .left_joins(:nuget_metadatum)
          .or(
            merge(Packages::Nuget::Metadatum.normalized_version_in(version))
          )
      end

      # Equivalent versions can be stored as separate packages, so the requested version comes first,
      # then, if it has build metadata, that version without it, then the newest. A stored
      # `2.0.0-alpha+build` has the version `2.0.0-alpha`, since build metadata does not change a NuGet version.
      scope :order_exact_version_first, ->(version) do
        version = version.downcase
        with_or_without_build_metadata = ->(value) do
          arel_table[:version].lower.eq(value).or(arel_table[:version].matches("#{sanitize_sql_like(value)}+%"))
        end
        first_rank = Arel::Nodes::Case.new.when(with_or_without_build_metadata.call(version)).then(0)
        exact_version =
          if version.include?('+')
            first_rank.when(with_or_without_build_metadata.call(version.partition('+').first)).then(1).else(2)
          else
            first_rank.else(1)
          end

        reorder(exact_version, created_at: :desc)
      end

      scope :including_dependency_links_with_nuget_metadatum, -> do
        includes(dependency_links: [:dependency, :nuget_metadatum])
      end

      scope :preload_nuget_metadatum, -> { preload(:nuget_metadatum) }
      scope :preload_nuget_files, -> { preload(:installable_nuget_package_files) }

      def self.installable_statuses
        INSTALLABLE_STATUSES
      end

      # @note The download endpoint looks up the same name, through {#same_version_as?}.
      # @param pushed_version [String]
      # @param symbol [Boolean]
      # @return [String]
      def nuget_file_name(pushed_version, symbol: false)
        file_version = same_version_as?(pushed_version) ? version : pushed_version

        "#{name.downcase}.#{file_version.downcase}.#{symbol ? 'snupkg' : 'nupkg'}"
      end

      # @note Compares lookup versions, not the stored normalized version, which can match a
      #   different prerelease label: `1.0-beta` is stored as `1.0-beta.0`.
      # @param other_version [String]
      # @return [Boolean]
      def same_version_as?(other_version)
        Packages::Nuget::Metadatum.normalized_lookup_version(other_version) ==
          Packages::Nuget::Metadatum.normalized_lookup_version(version)
      end
    end
  end
end
