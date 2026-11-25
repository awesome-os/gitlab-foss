# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ViteHelper, feature_category: :tooling do
  describe '#vite_page_entrypoint_paths' do
    using RSpec::Parameterized::TableSyntax

    let(:user) { build_stubbed(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'with varied page paths' do
      where(:path, :action, :result) do
        'some_path' | 'create' | %w[pages.some_path.js pages.some_path.new.js]
        'some_path' | 'new'    | %w[pages.some_path.js pages.some_path.new.js]
        'some_path' | 'update' | %w[pages.some_path.js pages.some_path.edit.js]
        'some_path' | 'show'   | %w[pages.some_path.js pages.some_path.show.js]
        'some/long' | 'path'   | %w[pages.some.js pages.some.long.js pages.some.long.path.js]
      end

      with_them do
        before do
          allow(helper.controller).to receive_messages(controller_path: path, action_name: action)
          allow(ViteRuby.instance.manifest).to receive(:path_for).and_return("/some/path")
        end

        it { expect(helper.vite_page_entrypoint_paths).to eq(result) }
      end
    end

    context 'with js_action_name instance variable set' do
      before do
        allow(helper.controller).to receive_messages(controller_path: 'some_path', action_name: 'new')
        allow(ViteRuby.instance.manifest).to receive(:path_for).and_return("/some/path")
      end

      it 'accepts custom action name' do
        expect(helper.vite_page_entrypoint_paths('new_2')).to eq(%w[pages.some_path.js pages.some_path.new_2.js])
      end
    end

    context 'with missing entrypoint' do
      before do
        allow(helper.controller).to receive_messages(controller_path: 'some_path', action_name: 'new')
        allow(ViteRuby.instance.manifest).to receive(:path_for).and_raise(
          ViteRuby::MissingEntrypointError.new(
            file_name: 'some/path.js',
            last_build: ViteRuby::Build.new,
            manifest: ViteRuby.instance.manifest,
            config: ViteRuby.instance.config
          )
        )
      end

      it 'returns empty assets' do
        expect(helper.vite_page_entrypoint_paths).to eq([])
      end

      it 'does not track the expected misses for ancestor route segments' do
        expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

        helper.vite_page_entrypoint_paths
      end
    end

    context 'with a missing Vue 3 entrypoint' do
      before do
        allow(helper.controller).to receive_messages(controller_path: 'some_path', action_name: 'new')
        allow(Gitlab::Vue3Migration).to receive(:entrypoint_for) { |name, **| name }
        allow(Gitlab::Vue3Migration).to receive(:entrypoint_for)
          .with('pages.some_path.new', current_user: user)
          .and_return('pages.some_path.new.vue3')

        allow(ViteRuby.instance.manifest).to receive(:path_for).and_return('/some/path')
        allow(ViteRuby.instance.manifest).to receive(:path_for)
          .with('pages.some_path.new.vue3.js')
          .and_raise(
            ViteRuby::MissingEntrypointError.new(
              file_name: 'pages.some_path.new.vue3.js',
              last_build: ViteRuby::Build.new,
              manifest: ViteRuby.instance.manifest,
              config: ViteRuby.instance.config
            )
          )
      end

      it 'drops the entrypoint but tracks it' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(ViteRuby::MissingEntrypointError),
          vue3_entrypoint: 'pages.some_path.new.vue3.js'
        )

        expect(helper.vite_page_entrypoint_paths).to eq(%w[pages.some_path.js])
      end
    end
  end
end
