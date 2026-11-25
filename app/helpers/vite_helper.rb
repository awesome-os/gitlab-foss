# frozen_string_literal: true

module ViteHelper
  def vite_enabled?
    # vite is not production ready yet
    return false if Rails.env.production?

    Gitlab::Utils.to_boolean(ViteRuby.env['VITE_ENABLED'], default: false)
  end

  def vite_page_entrypoint_paths(custom_action_name = nil)
    action_name = custom_action_name || controller.action_name
    action = case action_name
             when 'create' then 'new'
             when 'update' then 'edit'
             else action_name
             end

    parts = (controller.controller_path.split('/') << action)

    parts.map
         .with_index { |part, idx| "pages.#{(parts[0, idx] << part).join('.')}" }
         .map { |base| [base, ::Gitlab::Vue3Migration.entrypoint_for(base, current_user: current_user)] }
         .filter_map do |base, resolved|
           name = "#{resolved}.js"

           # always truthy in dev mode for non-existing entrypoints
           # we return /* doesn't exist */ on the dev server for such false positives
           name if ViteRuby.instance.manifest.path_for(name)
         rescue ViteRuby::MissingEntrypointError => e
           # we don't know if an entrypoint exists for each of the controller action part
           # for example: it might be present for the last part but not for the first part
           #   - pages.merge_requests.js -> empty, error thrown
           #   - pages.merge_requests.edit.js -> found
           #
           # A missing `.vue3` entry is not expected: dropping it leaves the
           # page with no entrypoint at all while its flag reads as enabled.
           ::Gitlab::ErrorTracking.track_exception(e, vue3_entrypoint: name) if resolved != base

           nil
         end
  end
end
