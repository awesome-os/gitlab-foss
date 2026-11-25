# frozen_string_literal: true

module GracefulTimeoutHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::QueryCanceled do |exception|
      raise exception unless request.format.json?

      log_exception(exception)
      @graceful_timeout = true

      render json: { error: _('There is too much data to calculate. Please change your selection.') }
    end
  end

  def append_info_to_payload(payload)
    super

    return unless @graceful_timeout # rubocop:disable Gitlab/ModuleWithInstanceVariables -- set by the rescue_from handler

    payload[:metadata] ||= {}
    payload[:metadata]['meta.graceful_timeout'] = true
  end
end
