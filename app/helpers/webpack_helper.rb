# frozen_string_literal: true

module WebpackHelper
  include ViteHelper

  def prefetch_link_tag(source)
    href = asset_path(source)

    link_tag = tag.link(rel: 'prefetch', href: href)

    early_hints_link = "<#{href}>; rel=prefetch"

    request.send_early_hints("Link" => early_hints_link)

    link_tag
  end

  def webpack_bundle_tag(bundle, **options)
    # `current_user` raises outside a Warden request, and helper and fixture specs
    # render bundle tags without one. Only a rollout entry needs the actor.
    entrypoint = if ::Gitlab::Vue3Migration.rollout?(bundle)
                   ::Gitlab::Vue3Migration.entrypoint_for(bundle, current_user: current_user)
                 else
                   bundle
                 end

    if vite_enabled?
      # ViteRuby appends `.js` only to a name with no extension, and `.vue3` reads as one.
      vite_javascript_tag(entrypoint == bundle ? bundle : "#{entrypoint}.js", **options)
    else
      javascript_include_tag(*webpack_entrypoint_paths(entrypoint), **options)
    end
  end

  def webpack_preload_asset_tag(asset, options = {})
    return if vite_enabled?

    path = Gitlab::Webpack::Manifest.asset_paths(asset, manifest_filename: bundler_manifest_filename).first

    if options.delete(:prefetch)
      prefetch_link_tag(path)
    else
      preload_link_tag(path, options)
    end
  rescue Gitlab::Webpack::Manifest::AssetMissingError
    # In development/test, incremental compilation may be enabled, meaning not
    # all chunks may be available/split out
    raise unless Gitlab.dev_or_test_env?
  end

  def webpack_controller_bundle_tags(custom_action_name = nil)
    chunks = []

    action_name = custom_action_name || controller.action_name
    action = case action_name
             when 'create' then 'new'
             when 'update' then 'edit'
             else action_name
             end

    route = [*controller.controller_path.split('/'), action].compact

    until chunks.any? || route.empty?
      base_entrypoint = "pages.#{route.join('.')}"
      entrypoint = ::Gitlab::Vue3Migration.entrypoint_for(base_entrypoint, current_user: current_user)
      begin
        chunks = webpack_entrypoint_paths(entrypoint, extension: 'js')
      rescue Gitlab::Webpack::Manifest::AssetMissingError => e
        # The bundler never built the Vue 3 variant for this page. Fall back to
        # the regular entry, and report it only once that fallback resolves:
        # Vue 2 and Vue 3 render the same UI, so nothing else reveals a no-op.
        if entrypoint != base_entrypoint
          begin
            chunks = webpack_entrypoint_paths(base_entrypoint, extension: 'js')

            # Static for the deploy: the manifest loads once per process, so
            # report per worker rather than per request.
            ::Gitlab::ProcessMemoryCache.cache_backend.fetch(
              "vue3_missing_bundle:#{entrypoint}", expires_in: 1.hour
            ) do
              ::Gitlab::ErrorTracking.track_exception(e, vue3_entrypoint: entrypoint)
            end
          rescue Gitlab::Webpack::Manifest::AssetMissingError
            # Neither entry is in this build, so no rollout is being skipped:
            # the page belongs to an edition this build did not compile.
          end
        end
      end
      route.pop
    end

    javascript_include_tag(*chunks)
  end

  def webpack_entrypoint_paths(source, extension: nil, exclude_duplicates: true)
    return "" unless source.present?

    paths = Gitlab::Webpack::Manifest.entrypoint_paths(source, manifest_filename: bundler_manifest_filename)
    paths.select! { |p| p.ends_with? ".#{extension}" } if extension

    force_host = webpack_public_host
    paths.map! { |p| "#{force_host}#{p}" } if force_host

    if exclude_duplicates
      @used_paths ||= []
      new_paths = paths - @used_paths
      @used_paths += new_paths
      new_paths
    else
      paths
    end
  end

  def webpack_public_host
    # We proxy webpack output in 'test' and 'dev' environment, so we can just use asset_host
    ActionController::Base.asset_host.try(:chomp, '/')
  end

  def rspack_enabled?
    return true if Rails.env.production?

    Gitlab::Utils.to_boolean(ENV['ENABLE_RSPACK'], default: Gitlab.config.webpack.bundler == 'rspack')
  end

  def bundler_manifest_filename
    rspack_enabled? ? Gitlab::Webpack::Manifest::RSPACK_MANIFEST_FILENAME : Gitlab.config.webpack.manifest_filename
  end

  def webpack_public_path
    relative_path = Gitlab.config.gitlab.relative_url_root
    webpack_path = Gitlab.config.webpack.public_path
    File.join(webpack_public_host.to_s, relative_path.to_s, webpack_path.to_s, '')
  end

  def universal_stylesheet_link_tag(path, **options)
    if vite_enabled?
      options[:extname] = false

      vite_stylesheet_tag(vite_css_entrypoint_name(path), **options)
    elsif rspack_stylesheets?
      rspack_stylesheet_link_tag(path, **options)
    else
      stylesheet_link_tag(path, **options)
    end
  end

  def universal_path_to_stylesheet(path, **options)
    if vite_enabled?
      ViteRuby.instance.manifest.path_for(vite_css_entrypoint_name(path), **options)
    elsif rspack_stylesheets?
      ActionController::Base.helpers.asset_path(rspack_stylesheet_paths(path).first)
    else
      ActionController::Base.helpers.stylesheet_path(path, **options)
    end
  end

  # Premailer inlines email stylesheets from the asset pipeline.
  def rspack_stylesheets?
    return false if respond_to?(:controller) && controller.is_a?(ActionMailer::Base)

    rspack_enabled? && Feature.enabled?(:rspack_stylesheets, :instance)
  end

  private

  # we must add `styles/` because ViteRuby prepends assets folder to the request if `/` is missing
  # we must use `.css` extension, otherwise Vite will not detect this as a CSS entrypoint
  def vite_css_entrypoint_name(path)
    "styles/#{path}.css"
  end

  def rspack_stylesheet_entrypoint(path)
    "styles/#{path}"
  end

  def rspack_stylesheet_manifest_paths(path)
    Gitlab::Webpack::Manifest
      .entrypoint_paths(rspack_stylesheet_entrypoint(path), manifest_filename: Gitlab::Webpack::Manifest::RSPACK_MANIFEST_FILENAME)
      .select { |p| p.end_with?('.css') }
  end

  def rspack_stylesheet_paths(path)
    rspack_stylesheet_manifest_paths(path).map { |p| "#{webpack_public_host}#{p}" }
  end

  def rspack_stylesheet_link_tag(path, **options)
    link_tags = stylesheet_link_tag(*rspack_stylesheet_paths(path), **options, extname: false)
    return link_tags unless rspack_stylesheet_hot_reload?

    # Hot module replacement swaps a stylesheet only when its entry script is on the page.
    entry_scripts = webpack_entrypoint_paths(rspack_stylesheet_entrypoint(path), extension: 'js')
    link_tags + javascript_include_tag(*entry_scripts)
  end

  def rspack_stylesheet_hot_reload?
    Gitlab.config.webpack.dev_server.enabled
  end
end
