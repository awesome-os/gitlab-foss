# frozen_string_literal: true

module Mcp
  module Tools
    module Concerns
      # The REST route behind `apply_suggestion` takes an integer id, but GraphQL returns a global ID.
      module SuggestionIdUnwrapping
        private

        def unwrap_suggestion_ids(merge_request)
          note_nodes = [
            merge_request.dig('notes', 'nodes'),
            merge_request.dig('discussions', 'nodes')&.flat_map { |discussion| discussion&.dig('notes', 'nodes') }
          ].flatten.compact

          note_nodes.each do |note|
            # Fine-grained tokens can get null discussion, note, and suggestion nodes.
            note.dig('suggestions', 'nodes')&.each do |suggestion|
              next unless suggestion

              gid = ::GlobalID.parse(suggestion['id'])
              suggestion['id'] = gid.model_id.to_i if gid
            end
          end

          merge_request
        end
      end
    end
  end
end
