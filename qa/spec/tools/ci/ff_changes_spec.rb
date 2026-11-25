# frozen_string_literal: true

RSpec.describe QA::Tools::Ci::FfChanges do
  subject(:ff_changes) { described_class.new(mr_diff) }

  before do
    allow(Gitlab::QA::TestLogger).to receive(:logger).and_return(Logger.new(StringIO.new))
  end

  context "with merge request pipeline" do
    let(:deleted_file) { false }
    let(:mr_diff) do
      [
        {
          path: "config/feature_flags/development/async_commit_diff_files.yml",
          deleted_file: deleted_file
        }
      ]
    end

    before do
      allow(File).to receive(:read)
        .with(File.expand_path("../#{mr_diff.first[:path]}", QA::Runtime::Path.qa_root))
        .and_return(File.read("spec/fixtures/ff/async_commit_diff_files.yml"))
    end

    context "with changed feature flag" do
      it "returns inverse ff state option" do
        expect(ff_changes.fetch).to eq("async_commit_diff_files=enabled")
      end
    end

    context 'with feature flags outside of development and ops' do
      let(:mr_diff) do
        [
          {
            path: "config/feature_flags/gitlab_com_derisk/async_commit_diff_files.yml",
            deleted_filed: false
          }
        ]
      end

      it "returns inverse ff state option" do
        expect(ff_changes.fetch).to eq("async_commit_diff_files=enabled")
      end
    end

    context "with deleted feature flag" do
      let(:deleted_file) { true }

      it "returns deleted ff state option" do
        expect(ff_changes.fetch).to eq("async_commit_diff_files=deleted")
      end
    end
  end

  describe "#only_additions_or_deletions?" do
    using RSpec::Parameterized::TableSyntax

    let(:new_flag) { { path: "config/feature_flags/development/new_flag.yml", new_file: true } }
    let(:deleted_flag) { { path: "config/feature_flags/development/old_flag.yml", deleted_file: true } }
    let(:changed_flag) { { path: "config/feature_flags/development/changed_flag.yml" } }
    let(:other_file) { { path: "app/models/project.rb" } }

    where(:changes, :expected) do
      %i[new_flag]                    | true
      %i[deleted_flag]                | true
      %i[new_flag deleted_flag]       | true
      %i[new_flag other_file]         | true
      %i[changed_flag]                | false
      %i[new_flag changed_flag]       | false
      %i[deleted_flag changed_flag]   | false
      %i[other_file]                  | false
    end

    with_them do
      let(:mr_diff) { changes.map { |change| public_send(change) } }

      it { expect(ff_changes.only_additions_or_deletions?).to be(expected) }
    end
  end

  context "without merge request pipeline" do
    let(:mr_diff) { [] }

    context "with empty mr diff" do
      it "doesn't return any ff options" do
        expect(ff_changes.fetch).to be_nil
      end

      it "does not report only additions or deletions" do
        expect(ff_changes.only_additions_or_deletions?).to be(false)
      end
    end
  end
end
