# frozen_string_literal: true

FactoryBot.define do
  factory :ml_candidate_latest_metrics, class: '::Ml::CandidateLatestMetric' do
    transient do
      metric { association(:ml_candidate_metrics) }
    end

    metric_id { metric.id }
    candidate { metric.candidate }
    project { candidate.project }
    experiment { candidate.experiment }
    name { metric.name }
    value { metric.value }
    step { metric.step }
    tracked_at { metric.tracked_at }
  end
end
