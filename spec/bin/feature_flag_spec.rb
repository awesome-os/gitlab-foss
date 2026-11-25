# frozen_string_literal: true

require 'spec_helper'

load File.expand_path('../../bin/feature-flag', __dir__)

RSpec.describe 'bin/feature-flag', feature_category: :feature_flags do
  using RSpec::Parameterized::TableSyntax

  let(:groups) do
    {
      geo: { label: 'group::geo', slack_channel: 'g_geo' }
    }
  end

  before do
    allow(HTTParty)
      .to receive(:get)
        .with(FeatureGenerator::Shared::WWW_GITLAB_COM_GROUPS_JSON, format: :plain)
        .and_return(groups.to_json)
  end

  describe FeatureFlagCreator do
    let(:argv) { %w[feature-flag-name -t gitlab_com_derisk -g group::geo -a https://url -i https://url -m https://url -u username -M 16.6 -ee] }
    let(:options) { FeatureFlagOptionParser.parse(argv) }
    let(:creator) { described_class.new(options) }
    let(:existing_flags) do
      {
        'existing_feature_flag' =>
          File.join('ee', 'config', 'feature_flags', 'gitlab_com_derisk', 'existing_feature_flag.yml')
      }
    end

    before do
      allow(creator).to receive(:all_feature_flag_names) { existing_flags }
      allow(creator).to receive_messages(branch_name: 'feature-branch', editor: nil)

      allow(File).to receive(:write).and_return(true)
      allow(Readline).to receive(:readline).and_raise('EOF')
      allow(Gitlab::Popen).to receive(:popen).and_return(["", 0])
    end

    subject(:execute) { creator.execute }

    it 'properly creates a feature flag', :aggregate_failures do
      expect(File).to receive(:write).with(
        File.join('ee', 'config', 'feature_flags', 'gitlab_com_derisk', 'feature_flag_name.yml'),
        anything)

      expect { execute }.to output(/name: feature_flag_name/).to_stdout
    end

    context 'when running on master' do
      it 'requires feature branch' do
        expect(creator).to receive(:branch_name).and_return('master')

        expect { execute }.to raise_error(FeatureGenerator::Shared::Abort, /Create a branch first/)
      end
    end

    context 'validates feature flag name' do
      where(:argv, :ex) do
        %w[.invalid.feature.flag] | /Provide a name for the feature flag that is/
        %w[existing-feature-flag] | /already exists!/
      end

      with_them do
        specify do
          expect { execute }.to raise_error(ex)
        end
      end
    end

    context 'when copy command not found' do
      let(:argv) { %w[feature-flag-name -t gitlab_com_derisk -g group::geo -a https://url -m https://url -u username -M 16.6 -e] }

      before do
        allow(Gitlab::Popen).to receive(:popen).and_return(["", 1])
      end

      it 'shows an error' do
        expect { execute }
          .to raise_error(FeatureGenerator::Shared::Abort, /Could not find a copy to clipboard command./)
      end

      context 'when the rollout issue description is written to a file' do
        let(:argv) do
          %w[feature-flag-name -t gitlab_com_derisk -g group::geo -a https://url -m https://url -u username -M 16.6 -e
            --rollout-issue-file tmp/issue.md]
        end

        before do
          allow(FileUtils).to receive(:mkdir_p)
        end

        it 'does not require a copy command' do
          expect { execute }.to output(/create/).to_stdout
        end
      end

      context 'when the rollout issue URL is given' do
        let(:argv) { super() + %w[-i https://url] }

        it 'does not require a copy command' do
          expect { execute }.to output(/create/).to_stdout
        end
      end
    end

    context 'without a rollout issue URL in interactive mode' do
      let(:argv) { %w[feature-flag-name -t gitlab_com_derisk -g group::geo -a https://url -m https://url -u username -M 16.6 -e] }

      it 'prompts for the rollout issue URL' do
        expect(FeatureFlagOptionParser).to receive(:read_rollout_issue_url).and_return('https://rollout')
        expect(File).to receive(:write).with(anything, %r{^rollout_issue_url: https://rollout$})

        expect { execute }.to output.to_stdout
      end
    end

    context 'with --amend in interactive mode' do
      let(:argv) { super() + %w[--amend] }

      it 'amends the commit with an editor' do
        expect(creator).to receive(:system).with('git', 'add', anything).and_return(true)
        expect(Kernel).to receive(:exec).with('git', 'commit', '--amend')

        expect { execute }.to output.to_stdout
      end
    end

    context 'with --rollout-issue-file in interactive mode' do
      let(:argv) do
        %w[feature-flag-name -t gitlab_com_derisk -g group::geo -a https://url -m https://url -u username -M 16.6 -e
          --rollout-issue-file tmp/issue.md]
      end

      before do
        allow(FileUtils).to receive(:mkdir_p)
      end

      it 'writes the rollout issue description to the file instead of prompting', :aggregate_failures do
        expect(FeatureFlagOptionParser).not_to receive(:read_rollout_issue_url)
        expect(File).to receive(:write).with('tmp/issue.md', /feature_flag_name/)

        expect { execute }.to output(%r{create\e\[0m tmp/issue.md}).to_stdout
      end
    end

    context 'with --non-interactive' do
      let(:base_argv) { %w[feature-flag-name --non-interactive -M 16.6] }
      let(:argv) { base_argv + %w[-t gitlab_com_derisk -g group::geo] }
      let(:default_rollout_issue_file) { File.join('tmp', 'feature_flags', 'feature_flag_name_rollout_issue.md') }

      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow(Gitlab::Popen).to receive(:popen).and_return(["", 1])
      end

      it 'creates the flag and rollout issue file without prompting', :aggregate_failures do
        expect(Readline).not_to receive(:readline)
        expect(FeatureFlagOptionParser).not_to receive(:prompt_list)
        expect(FeatureFlagOptionParser).not_to receive(:copy_to_clipboard!)
        expect(File).to receive(:write).with(
          File.join('config', 'feature_flags', 'gitlab_com_derisk', 'feature_flag_name.yml'),
          /^rollout_issue_url:\s*$/)
        expect(File).to receive(:write).with(default_rollout_issue_file, /feature_flag_name/)

        expect { execute }.to output(/Suggested title: \[FF\] `feature_flag_name`/).to_stdout
      end

      context 'with --rollout-issue-file' do
        let(:argv) { super() + %w[--rollout-issue-file tmp/issue.md] }

        it 'writes the rollout issue description to the given file' do
          expect(File).to receive(:write).with('tmp/issue.md', /feature_flag_name/)

          expect { execute }.to output.to_stdout
        end
      end

      context 'with --rollout-issue-url' do
        let(:argv) { super() + %w[-i https://url] }

        it 'does not write a rollout issue file' do
          expect(File).not_to receive(:write).with(default_rollout_issue_file, anything)

          expect { execute }.to output.to_stdout
        end
      end

      context 'when the type does not need a rollout issue' do
        let(:argv) { base_argv + %w[-t wip -g group::geo] }

        it 'does not write a rollout issue file' do
          expect(File).not_to receive(:write).with(default_rollout_issue_file, anything)

          expect { execute }.to output.to_stdout
        end

        context 'with --rollout-issue-file' do
          let(:argv) { super() + %w[--rollout-issue-file tmp/issue.md] }

          it 'does not write the given file' do
            expect(File).not_to receive(:write).with('tmp/issue.md', anything)

            expect { execute }.to output.to_stdout
          end
        end
      end

      context 'with --dry-run' do
        let(:argv) { super() + %w[--dry-run] }

        it 'does not write any file' do
          expect(File).not_to receive(:write)

          expect { execute }.to output(/create.*#{Regexp.escape(default_rollout_issue_file)}/).to_stdout
        end
      end

      context 'with an editor configured' do
        before do
          allow(creator).to receive(:editor).and_return('vim')
        end

        it 'does not open the editor' do
          expect(creator).not_to receive(:system)

          expect { execute }.to output.to_stdout
        end
      end

      context 'with --amend' do
        let(:argv) { super() + %w[--amend] }

        it 'amends the commit without opening an editor' do
          expect(creator).to receive(:system).with('git', 'add', anything).and_return(true)
          expect(Kernel).to receive(:exec).with('git', 'commit', '--amend', '--no-edit')

          expect { execute }.to output.to_stdout
        end
      end

      context 'with a missing or invalid option' do
        where(:extra_argv, :error) do
          %w[-g group::geo]                    | /Provide a valid --type.*Valid types: gitlab_com_derisk/
          %w[-t invalid -g group::geo]         | /Provide a valid --type/
          %w[-t development -g group::geo]     | /Provide a valid --type/
          %w[-t gitlab_com_derisk]             | /Provide a valid --group.*Valid groups: group::geo/
          %w[-t gitlab_com_derisk -g invalid]  | /Provide a valid --group/
        end

        with_them do
          let(:argv) { base_argv + extra_argv }

          it 'fails without prompting' do
            expect(Readline).not_to receive(:readline)

            expect { execute }.to raise_error(FeatureGenerator::Shared::Abort, error)
          end
        end
      end
    end
  end

  describe FeatureFlagOptionParser do
    describe '.parse' do
      where(:param, :argv, :result) do
        :name               | %w[foo]                                 | 'foo'
        :amend              | %w[foo --amend]                         | true
        :force              | %w[foo -f]                              | true
        :force              | %w[foo --force]                         | true
        :ee                 | %w[foo -e]                              | true
        :ee                 | %w[foo --ee]                            | true
        :introduced_by_url  | %w[foo -m https://url]                  | 'https://url'
        :introduced_by_url  | %w[foo --introduced-by-url https://url] | 'https://url'
        :rollout_issue_url  | %w[foo -i https://url]                  | 'https://url'
        :rollout_issue_url  | %w[foo --rollout-issue-url https://url] | 'https://url'
        :dry_run            | %w[foo -n]                              | true
        :dry_run            | %w[foo --dry-run]                       | true
        :type               | %w[foo -t development]                  | :development
        :type               | %w[foo --type development]              | :development
        :type               | %w[foo -t invalid]                      | nil
        :type               | %w[foo --type invalid]                  | nil
        :group              | %w[foo -g group::geo]                   | 'group::geo'
        :group              | %w[foo --group group::geo]              | 'group::geo'
        :group              | %w[foo -g invalid]                      | nil
        :group              | %w[foo --group invalid]                 | nil
        :rollout_issue_file | %w[foo --rollout-issue-file tmp/a.md]   | 'tmp/a.md'
        :non_interactive    | %w[foo --non-interactive]               | true
      end

      with_them do
        specify do
          options = described_class.parse(Array(argv))

          expect(options.public_send(param)).to eq(result)
        end
      end

      it 'missing feature flag name' do
        expect do
          expect { described_class.parse(%w[--amend]) }.to output(/Feature flag name is required/).to_stdout
        end.to raise_error(FeatureGenerator::Shared::Abort)
      end

      it 'parses -h' do
        expect do
          expect { described_class.parse(%w[foo -h]) }.to output(/Usage:/).to_stdout
        end.to raise_error(FeatureGenerator::Shared::Done)
      end
    end

    describe '.read_type' do
      before do
        stub_const('FeatureFlagOptionParser::TYPES',
          development: { description: 'short' },
          deprecated: { description: 'deprecated', deprecated: true },
          licensed: { description: 'licensed' }
        )
        allow(described_class).to receive(:fzf_available?).and_return(false)
      end

      context 'when valid type is given' do
        let(:type) { 'development' }

        it 'reads type from stdin' do
          expect(Readline).to receive(:readline).and_return(type)
          expect do
            expect(described_class.read_type).to eq(:development)
          end.to output(/Specify the feature flag type/).to_stdout
        end
      end

      context 'when valid index is given' do
        it 'picks the type successfully' do
          expect(Readline).to receive(:readline).and_return('3')
          expect do
            expect(described_class.read_type).to eq(:licensed)
          end.to output(/Specify the feature flag type./).to_stdout
        end
      end

      context 'when deprecated type is given' do
        let(:type) { 'deprecated' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(type)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_type }.to raise_error(/EOF/)
          end.to output(/Specify the feature flag type/).to_stdout
            .and output(/Invalid type specified/).to_stderr
        end
      end

      context 'when invalid type is given' do
        let(:type) { 'invalid' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(type)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_type }.to raise_error(/EOF/)
          end.to output(/Specify the feature flag type/).to_stdout
            .and output(/Invalid type specified/).to_stderr
        end
      end

      context 'when invalid index is given' do
        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return('12')
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_type }.to raise_error(/EOF/)
          end.to output(/Specify the feature flag type/).to_stdout
            .and output(/Invalid type specified/).to_stderr
        end
      end
    end

    describe '.read_group' do
      it 'uses the feature flag noun in the prompt' do
        allow(described_class).to receive(:fzf_available?).and_return(false)
        expect(Readline).to receive(:readline).and_return('group::geo')

        expect { described_class.read_group }
          .to output(/feature flag/).to_stdout
      end
    end

    describe '.read_feature_issue_url' do
      it 'prompts for the original feature issue URL' do
        expect(Readline).to receive(:readline).and_return('')

        expect { described_class.read_feature_issue_url }
          .to output(/URL of the original feature issue/).to_stdout
      end
    end

    describe '.read_introduced_by_url' do
      it 'uses the feature flag noun in the prompt' do
        expect(Readline).to receive(:readline).and_return('')

        expect { described_class.read_introduced_by_url }
          .to output(/introducing the feature flag/).to_stdout
      end
    end

    describe '.read_username' do
      it 'returns nil on Ctrl-D without raising NoMethodError' do
        expect(Readline).to receive(:readline).and_return(nil)

        expect { expect(described_class.read_username).to be_nil }
          .to output(/Username of the feature flag DRI/).to_stdout
      end
    end

    describe '.read_ee' do
      context 'with valid ee setting is given' do
        let(:ee) { '1' }

        it 'reads ee from stdin', :aggregate_failures do
          expect(Readline).to receive(:readline).and_return(ee)
          expect do
            expect(described_class.read_ee).to be(true)
          end.to output(/Is this an EE only feature/).to_stdout
        end
      end

      it 'returns nil on Ctrl-D without raising NoMethodError' do
        expect(Readline).to receive(:readline).and_return(nil)

        expect { expect(described_class.read_ee).to be_nil }
          .to output(/Is this an EE only feature/).to_stdout
      end
    end

    describe '.rollout_issue_description' do
      let(:options) do
        FeatureFlagOptionParser::Options.new({
          name: 'foo_flag',
          username: 'joe',
          type: :gitlab_com_derisk,
          introduced_by_url: 'https://example.com/mr',
          feature_issue_url: 'https://example.com/issue',
          milestone: '16.6',
          group: 'group::geo'
        })
      end

      # Guards against the rollout issue template renaming a placeholder that the script fills in.
      it 'fills every placeholder in the rollout issue template', :aggregate_failures do
        description = described_class.rollout_issue_description(options)

        expect(description).to include(
          '`foo_flag`', '@joe', 'https://example.com/mr', 'https://example.com/issue',
          'release check https://example.com/mr 16.6', '#g_geo', '/label ~"group::geo"'
        )
        expect(description).not_to include(
          '<feature-flag-name>', '<gitlab-username-of-dri>', '<merge-request-url>', '<milestone>',
          '<feature-issue-link>', '<slack-channel-of-dri-team>', '<group-label>'
        )
      end

      it 'assigns the current user when no username is given' do
        options.username = nil

        expect(described_class.rollout_issue_description(options)).to include('/assign me')
      end

      it 'does not modify the cached template between calls' do
        described_class.rollout_issue_description(options)
        options.name = 'bar_flag'

        expect(described_class.rollout_issue_description(options)).to include('`bar_flag`')
      end
    end

    describe '.read_rollout_issue_url' do
      let(:options) do
        FeatureFlagOptionParser::Options.new({
          name: 'foo',
          username: 'joe',
          type: :gitlab_com_derisk,
          introduced_by_url: 'https://introduced_by_url',
          feature_issue_url: 'https://feature_issue_url',
          milestone: '16.6',
          group: 'group::geo'
        })
      end

      context 'with valid URL given' do
        let(:url) { 'https://rollout_issue_url' }

        it 'reads type from stdin' do
          expect(described_class).to receive(:copy_to_clipboard!).and_return(true)
          expect(Readline).to receive(:readline).and_return('') # enter to open the new issue url
          expect(described_class).to receive(:open_url!).and_return(true)
          expect(Readline).to receive(:readline).and_return(url)
          expect(HTTParty).to receive(:head).with(url).and_return(instance_double(HTTParty::Response, success?: true))

          expect do
            expect(described_class.read_rollout_issue_url(options)).to eq(url)
          end.to output(/URL of the rollout issue/).to_stdout
        end
      end

      context 'with invalid URL given' do
        let(:url) { 'https://invalid' }

        it 'shows error message and retries' do
          expect(described_class).to receive(:copy_to_clipboard!).and_return(true)
          expect(Readline).to receive(:readline).and_return('') # enter to open the new issue url
          expect(described_class).to receive(:open_url!).and_return(true)
          expect(Readline).to receive(:readline).and_return(url)
          expect(HTTParty).to receive(:head).with(url).and_return(instance_double(HTTParty::Response, success?: false))
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_rollout_issue_url(options) }.to raise_error(/EOF/)
          end.to output(/URL of the rollout issue/).to_stdout
            .and output(/URL '#{url}' isn't valid/).to_stderr
        end
      end

      context 'with a non-URL given' do
        let(:url) { 'malformed' }

        it 'shows error message and retries' do
          expect(described_class).to receive(:copy_to_clipboard!).and_return(true)
          expect(Readline).to receive(:readline).and_return('') # enter to open the new issue url
          expect(described_class).to receive(:open_url!).and_return(true)
          expect(Readline).to receive(:readline).and_return(url)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_rollout_issue_url(options) }.to raise_error(/EOF/)
          end.to output(/URL of the rollout issue/).to_stdout
            .and output(/URL needs to start/).to_stderr
        end
      end
    end
  end
end
