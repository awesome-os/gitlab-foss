# frozen_string_literal: true

module Gitlab
  module Routing
    # A route constraint resolves a routable to decide whether the route matches, and the
    # controller that serves the route then needs the same record. The constraint leaves it
    # in the Rack env so `RoutableActions#find_routable!` can reuse it instead of repeating
    # the lookup. Only a lookup made with the same class, path and `follow_redirects` is
    # reused; anything else falls back to `find_by_full_path`.
    module ConstraintLookup
      ENV_KEY = 'gitlab.routing.constraint_lookup'

      class << self
        def store(request, routable_klass, full_path, follow_redirects, routable)
          request.env[ENV_KEY] = [routable_klass, full_path, follow_redirects, routable]
        end

        def fetch(request, routable_klass, full_path, follow_redirects)
          stored_klass, stored_path, stored_follow_redirects, routable = request.env[ENV_KEY]

          # stored_klass on the left: routable_klass can be a relation, whose #== loads it.
          return unless stored_klass == routable_klass &&
            stored_path == full_path &&
            stored_follow_redirects == follow_redirects

          routable
        end
      end
    end
  end
end
