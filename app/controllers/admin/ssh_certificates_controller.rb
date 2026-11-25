# frozen_string_literal: true

module Admin
  class SshCertificatesController < Admin::ApplicationController
    feature_category :repository_services
    urgency :low

    # `not_found` rather than `forbidden` keeps the page's existence unadvertised on
    # GitLab.com, where instance-level certificate authorities never apply.
    before_action :not_found, unless: -> { InstanceSshCertificate.available? }

    def index; end
  end
end
