# frozen_string_literal: true

# Fresh installations load db/structure.sql and mark every migration as run, so the
# SeedFirstPartyOauthApplications migration only ever runs on upgrades. Runs after 002_default_organization.rb.
Gitlab::Seeder.quiet do
  Gitlab::DatabaseImporters::FirstPartyOauthApplicationsImporter.seed
end
