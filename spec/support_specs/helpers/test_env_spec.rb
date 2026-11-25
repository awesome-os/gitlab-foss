# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TestEnv, feature_category: :tooling do
  describe '.install_mise_tools_for' do
    subject(:install_tools) { described_class.send(:install_mise_tools_for, dir) }

    let(:dir) { '/component' }
    let(:mise_data) { '/mise' }
    let(:shims) { File.join(mise_data, 'shims') }
    let(:path) { "/mise/installs/go/1.25.5/bin:#{shims}:/usr/bin" }

    before do
      stub_env('GL_AUTOINSTALL_TEST_DEPS', '1')
      stub_env('CI', nil)
      stub_env('MISE_DATA_DIR', mise_data)
      stub_env('PATH', path)

      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(dir, '.tool-versions')).and_return(true)
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:directory?).with(shims).and_return(true)
      allow(described_class).to receive(:system).with('mise', 'trust', '--yes', File.join(dir, '.tool-versions'))
      allow(described_class).to receive(:system).with('mise', 'install')
      allow(Dir).to receive(:chdir).with(dir).and_yield
    end

    it 'moves existing shims ahead of globally activated tools' do
      expect(ENV).to receive(:[]=).with('PATH', "#{shims}:/mise/installs/go/1.25.5/bin:/usr/bin")

      install_tools
    end

    context 'when shims are missing from PATH' do
      let(:path) { '/usr/local/bin:/usr/bin' }

      it 'prepends shims and preserves the other entries' do
        expect(ENV).to receive(:[]=).with('PATH', "#{shims}:#{path}")

        install_tools
      end
    end

    context 'when shims appear more than once' do
      let(:path) { "#{shims}:/usr/local/bin:#{shims}:/usr/bin" }

      it 'keeps a single shims entry at the front' do
        expect(ENV).to receive(:[]=).with('PATH', "#{shims}:/usr/local/bin:/usr/bin")

        install_tools
      end
    end

    context 'when the shims directory does not exist' do
      before do
        allow(File).to receive(:directory?).with(shims).and_return(false)
      end

      it 'leaves PATH unchanged' do
        expect(ENV).not_to receive(:[]=).with('PATH', anything)

        install_tools
      end
    end
  end
end
