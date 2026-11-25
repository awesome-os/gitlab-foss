# frozen_string_literal: true

require 'tmpdir'
require 'spec_helper'
require './keeps/helpers/rubocop_grace_period_remover'

RSpec.describe Keeps::Helpers::RubocopGracePeriodRemover, :freeze_time, feature_category: :tooling do
  let(:todo_dir) { Dir.mktmpdir }
  let(:grace_period_file) { Pathname(todo_dir).join('grace_period.yml').to_s }
  let(:head_revision) { 'abc123' }
  let(:api_helper) { instance_double(Keeps::Helpers::GitlabApiHelper) }

  subject(:remover) { described_class.new }

  before do
    FileUtils.cp('spec/fixtures/keeps/rubocop_grace_period.yml', grace_period_file)

    allow(Keeps::Helpers::GitlabApiHelper).to receive(:new).and_return(api_helper)
    allow(::Gitlab::Housekeeper::Shell).to receive(:execute)
      .with('git', 'rev-parse', 'HEAD')
      .and_return("#{head_revision}\n")

    stub_git_grep_files("#{grace_period_file}\n")
    stub_committed_line(grace_period_file, 4)
  end

  after do
    FileUtils.remove_entry(todo_dir)
  end

  def stub_git_grep_files(output)
    allow(::Gitlab::Housekeeper::Shell).to receive(:execute)
      .with('git', 'grep', '--files-with-matches', '--fixed-strings', described_class::KEY_VALUE,
        '--', described_class::TODO_DIR_PATTERN)
      .and_return(output)
  end

  def stub_committed_line(file, line)
    stub = allow(::Gitlab::Housekeeper::Shell).to receive(:execute)
      .with('git', 'grep', '--line-number', '--fixed-strings', described_class::KEY_VALUE, head_revision, '--', file)

    if line
      stub.and_return("#{head_revision}:#{file}:#{line}:  #{described_class::KEY_VALUE}\n")
    else
      stub.and_raise(::Gitlab::Housekeeper::Shell::Error, 'not found')
    end
  end

  def stub_blame(results)
    allow(api_helper).to receive(:get).and_return({ results: results })
  end

  def blame_committed_at(time)
    [{ 'commit' => { 'committed_date' => time.iso8601 }, 'lines' => ["  #{described_class::KEY_VALUE}"] }]
  end

  def grace_period_kept?
    File.read(grace_period_file).include?(described_class::KEY_VALUE)
  end

  describe '#remove_overdue' do
    context 'when the grace period line was added MIN_AGE_DAYS ago or earlier' do
      before do
        stub_blame(blame_committed_at(described_class::MIN_AGE_DAYS.days.ago))
      end

      it 'removes the grace period line while preserving other content', :aggregate_failures do
        remover.remove_overdue

        content = File.read(grace_period_file)

        expect(content).not_to include('Details: grace period')
        expect(content).to include('RuboCop/FakeGracePeriodRule')
        expect(content).to include("- 'app/models/fake1.rb'")
        expect(content).to include("- 'app/models/fake2.rb'")
      end

      it 'deletes the todo file when the grace period was its only setting' do
        File.write(grace_period_file, <<~YAML)
          ---
          # Cop supports --autocorrect.
          Layout/EmptyLines:
            Details: grace period
        YAML

        remover.remove_overdue

        expect(File.exist?(grace_period_file)).to be(false)
      end

      it 'asks the blame API for the grace period line at HEAD' do
        path = ERB::Util.url_encode(grace_period_file)

        expect(api_helper).to receive(:get).with(
          "https://gitlab.com/api/v4/projects/gitlab-org%2Fgitlab/repository/files/#{path}/blame" \
            "?ref=#{head_revision}&range[start]=4&range[end]=4"
        )

        remover.remove_overdue
      end
    end

    context 'when the grace period line was added less than MIN_AGE_DAYS ago' do
      before do
        stub_blame(blame_committed_at((described_class::MIN_AGE_DAYS - 1).days.ago))
      end

      it 'keeps the grace period line' do
        remover.remove_overdue

        expect(grace_period_kept?).to be(true)
      end
    end

    context 'when the grace period line is not at HEAD' do
      before do
        stub_committed_line(grace_period_file, nil)
      end

      it 'keeps the grace period line without calling the API' do
        expect(api_helper).not_to receive(:get)

        remover.remove_overdue

        expect(grace_period_kept?).to be(true)
      end
    end

    context 'when the git grep output has no line number' do
      before do
        allow(::Gitlab::Housekeeper::Shell).to receive(:execute)
          .with('git', 'grep', '--line-number', '--fixed-strings', described_class::KEY_VALUE, head_revision,
            '--', grace_period_file)
          .and_return("unexpected output\n")
      end

      it 'keeps the grace period line without calling the API' do
        expect(api_helper).not_to receive(:get)

        remover.remove_overdue

        expect(grace_period_kept?).to be(true)
      end
    end

    context 'when the blame API returns an error' do
      before do
        stub_blame({ 'message' => '404 File Not Found' })
      end

      it 'logs the error and keeps the grace period line' do
        expect(remover).to receive(:warn).with(/blame of .*:4 failed: .*404 File Not Found/)

        remover.remove_overdue

        expect(grace_period_kept?).to be(true)
      end
    end

    context 'when the blame request raises' do
      before do
        allow(api_helper).to receive(:get).and_raise(SocketError, 'boom')
      end

      it 'logs the error and keeps the grace period line' do
        expect(remover).to receive(:warn).with(/blame of .*:4 failed: boom/)

        remover.remove_overdue

        expect(grace_period_kept?).to be(true)
      end
    end

    context 'when git grep finds no files (exits non-zero)' do
      before do
        allow(::Gitlab::Housekeeper::Shell).to receive(:execute)
          .with('git', 'grep', '--files-with-matches', '--fixed-strings', described_class::KEY_VALUE,
            '--', described_class::TODO_DIR_PATTERN)
          .and_raise(::Gitlab::Housekeeper::Shell::Error, 'no match')
      end

      it 'logs the error, treats it as no files, and does nothing' do
        expect(remover).to receive(:warn).with(/git grep found no files with a grace period: no match/)
        expect(api_helper).not_to receive(:get)

        remover.remove_overdue

        expect(grace_period_kept?).to be(true)
      end
    end
  end
end
