# frozen_string_literal: true

class Gitlab::Seeder::FlipperFeatureFlags # rubocop:disable Style/ClassAndModuleChildren -- seeder convention
  FLAGS = {
    'seeded_boolean_flag' => { 'boolean' => 'true' },
    'seeded_percentage_flag' => { 'percentage_of_time' => '50', 'percentage_of_actors' => '10' },
    'seeded_null_gate_flag' => { 'percentage_of_time' => nil }
  }.freeze

  def seed!
    FLAGS.each do |feature_key, gates|
      ::Feature::FlipperFeature.find_or_create_by!(key: feature_key)

      gates.each do |key, value|
        ::Feature::FlipperGate.find_or_create_by!(feature_key: feature_key, key: key) { |gate| gate.value = value }
      end
    end

    ::Feature.expire_features_cache
    print '.'
  end
end

Gitlab::Seeder.quiet do
  puts "\nGenerating Flipper feature flag data"

  Gitlab::Seeder::FlipperFeatureFlags.new.seed!
end
