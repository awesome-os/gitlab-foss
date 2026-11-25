# frozen_string_literal: true

# Seeds ml_candidate_latest_metrics so migrations touching it are exercised by db:migrate:multi-version-upgrade.
# Covers a name logged twice (the second value wins), NaN and negative values, a non-ASCII and an empty name,
# and a metric without step and timestamp.
class Gitlab::Seeder::MlCandidateLatestMetrics # rubocop:disable Style/ClassAndModuleChildren -- seeder convention
  NAME = 'seeded-latest-metrics'

  def seed!
    project = Project.order(:id).first
    return warn "\nSkipping ML latest metric seeds: no project" unless project

    experiment = Ml::Experiment.find_or_create_by!(project: project, name: NAME)
    candidate = experiment.candidates.find_by(name: NAME) ||
      Ml::CreateCandidateService.new(experiment, name: NAME).execute
    return puts "\nML latest metrics already seeded" if Ml::CandidateLatestMetric.exists?(candidate_id: candidate.id)

    Ml::CandidateLatestMetric.insert_metrics(candidate, [
      { name: 'loss', value: 0.5, step: 0, tracked_at: 1_700_000_000_000 },
      { name: 'loss', value: 0.25, step: 1, tracked_at: 1_700_000_001_000 },
      { name: 'accuracy', value: Float::NAN, step: 0, tracked_at: 0 },
      { name: 'durée_époque', value: 12.5, step: nil, tracked_at: nil },
      { name: '', value: -1.0, step: -1, tracked_at: -1 }
    ])
    puts "\nInserted ML latest metrics for candidate #{candidate.id}"
  end
end

Gitlab::Seeder.quiet do
  puts "\nGenerating ML candidate latest metrics"

  Gitlab::Seeder::MlCandidateLatestMetrics.new.seed!
end
