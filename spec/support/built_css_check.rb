# frozen_string_literal: true

# CSS is built by Node (`yarn build:css`), not by Sprockets. In a checkout that never
# built it, resolving a stylesheet makes Sprockets compile the `.scss` itself and raise
# `LoadError: cannot load such file -- sass`.

# The fixtures mapping job records which fixture each spec writes without running it,
# so it renders nothing and has no compiled assets to check.
return if ENV['GENERATE_FRONTEND_FIXTURES_MAPPING'] == 'true'

RSpec.configure do |config|
  registered = false

  %i[controller request feature mailer view].each do |type|
    config.when_first_matching_example_defined(type: type) do
      next if registered

      registered = true

      config.before(:suite) do
        # Mapping mode records fixture file names without rendering any page.
        next if ENV['GENERATE_FRONTEND_FIXTURES_MAPPING'] == 'true'

        # The same helper `add_gon_variables` uses: with Vite enabled it reads the Vite
        # manifest and never touches Sprockets, so only Sprockets runs can abort here.
        ApplicationController.helpers.universal_path_to_stylesheet('emoji_sprites')
      rescue LoadError => e
        raise unless e.path == 'sass'

        abort <<~MESSAGE
          Controller, request, feature, mailer, and view specs need the application CSS
          to have been built once, or rendering HTML fails with the misleading error
          `LoadError: cannot load such file -- sass`.

          Build it with:

            yarn build:css

          then run RSpec again.
        MESSAGE
      end
    end
  end
end
