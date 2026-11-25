# frozen_string_literal: true

RSpec.describe QA::Tools::Ci::E2eSelectionDecision, feature_category: :tooling do
  include QA::Support::Helpers::StubEnv

  subject(:decision) { described_class.new(mr_labels: labels, mr_diff: -> { mr_diff }) }

  let(:labels) { ["pipeline::tier-3"] }
  let(:mr_diff) { [{ path: "app/models/user.rb", diff: "" }] }
  let(:qa_changes) do
    instance_double(QA::Tools::Ci::QaChanges,
      quarantine_changes?: false,
      only_spec_removal?: false,
      only_changes_to_non_e2e_spec_files?: false,
      framework_changes?: false,
      qa_tests: ["qa/specs/features/test_spec.rb"])
  end

  let(:ff_changes) { instance_double(QA::Tools::Ci::FfChanges, fetch: nil, only_additions_or_deletions?: false) }

  before do
    allow(QA::Tools::Ci::QaChanges).to receive(:new).and_return(qa_changes)
    allow(QA::Tools::Ci::FfChanges).to receive(:new).and_return(ff_changes)
    stub_env("SELECTIVE_EXECUTION_IMPROVED", "true")
    stub_env("FRONTEND_SELECTIVE_EXECUTION", "false")
    stub_env("CI_MERGE_REQUEST_TARGET_BRANCH_NAME", "master")
  end

  shared_examples "a noop" do |reason|
    it "skips E2E with reason #{reason}" do
      expect(decision).to have_attributes(reason: reason, noop?: true, selective?: false)
      expect(decision.message).to be_a(String)
    end
  end

  shared_examples "a full suite run" do |reason|
    it "runs the full suite with reason #{reason}" do
      expect(decision).to have_attributes(reason: reason, noop?: false, selective?: false, tests: [])
    end
  end

  it "raises when both the skip and run-all labels are set" do
    labels = %w[pipeline:skip-e2e pipeline:run-all-e2e]

    expect { described_class.new(mr_labels: labels, mr_diff: -> { raise "fetched" }) }
      .to raise_error(ArgumentError, /cannot have both/)
  end

  context "with the skip label" do
    let(:labels) { ["pipeline:skip-e2e"] }

    it_behaves_like "a noop", :skip_label

    it "does not fetch the MR diff" do
      decision = described_class.new(mr_labels: labels, mr_diff: -> { raise "fetched" })

      expect(decision.reason).to eq(:skip_label)
    end
  end

  context "with only quarantine changes" do
    before do
      allow(qa_changes).to receive(:quarantine_changes?).and_return(true)
    end

    it_behaves_like "a noop", :quarantine

    context "with the run-all label" do
      let(:labels) { ["pipeline:run-all-e2e"] }

      it_behaves_like "a full suite run", :run_all_label
    end
  end

  context "with only spec removals" do
    before do
      allow(qa_changes).to receive(:only_spec_removal?).and_return(true)
    end

    it_behaves_like "a noop", :spec_removal
  end

  context "with only non E2E spec changes" do
    before do
      allow(qa_changes).to receive(:only_changes_to_non_e2e_spec_files?).and_return(true)
    end

    it_behaves_like "a noop", :non_e2e_changes
  end

  context "with an empty diff" do
    let(:mr_diff) { [] }

    it_behaves_like "a full suite run", :empty_diff

    it "does not look for feature flag changes" do
      expect(decision.feature_flags).to be_nil
      expect(ff_changes).not_to have_received(:fetch)
    end
  end

  context "with framework changes" do
    before do
      allow(qa_changes).to receive(:framework_changes?).and_return(true)
    end

    it_behaves_like "a full suite run", :framework_changes
  end

  context "with feature flag changes" do
    before do
      allow(ff_changes).to receive(:fetch).and_return("my_flag=enabled")
    end

    it_behaves_like "a full suite run", :feature_flags

    it "returns the flag states" do
      expect(decision.feature_flags).to eq("my_flag=enabled")
    end

    context "when every changed flag is new or deleted" do
      before do
        allow(ff_changes).to receive(:only_additions_or_deletions?).and_return(true)
      end

      it "still allows selection" do
        expect(decision.reason).to eq(:selective)
      end
    end
  end

  context "without a tier label" do
    let(:labels) { [] }

    it "is not eligible and keeps the changed specs" do
      expect(decision).to have_attributes(reason: :not_eligible, selective?: false,
        tests: ["qa/specs/features/test_spec.rb"])
    end
  end

  context "when targeting a stable branch" do
    before do
      stub_env("CI_MERGE_REQUEST_TARGET_BRANCH_NAME", "18-5-stable-ee")
    end

    it "is not eligible" do
      expect(decision.reason).to eq(:not_eligible)
    end
  end

  context "when selective execution is turned off" do
    before do
      stub_env("SELECTIVE_EXECUTION_IMPROVED", "false")
    end

    it "is not eligible" do
      expect(decision.reason).to eq(:not_eligible)
    end
  end

  context "with a tier label and selection turned on" do
    it "selects specs" do
      expect(decision).to have_attributes(reason: :selective, selective?: true, noop?: false,
        pipeline_tier: "pipeline::tier-3")
    end
  end
end
