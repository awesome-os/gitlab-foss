# frozen_string_literal: true

module API
  module Validations
    module Validators
      # Rejects nil and the empty string. Unlike `allow_blank: false`, it accepts a whitespace-only string.
      class NotEmpty < Grape::Validations::Validators::Base
        def validate_param!(attr_name, params)
          return unless params.respond_to?(:key?) && params.key?(attr_name)
          return unless params[attr_name].nil? || params[attr_name] == ''

          raise Grape::Exceptions::Validation.new(params: [@scope.full_name(attr_name)], message: 'is empty')
        end
      end
    end
  end
end
