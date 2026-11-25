# frozen_string_literal: true

module RapidDiffs
  class CommitAppComponent < ViewComponent::Base
    attr_reader :presenter

    delegate :discussions_endpoint, :user_permissions, :noteable_type,
      :preview_markdown_endpoint, :markdown_docs_path, :register_path, :sign_in_path,
      :report_abuse_path, :new_comment_template_paths, to: :presenter

    def initialize(presenter)
      @presenter = presenter
    end

    protected

    def extra_app_data
      {
        user_permissions: user_permissions,
        discussions_endpoint: discussions_endpoint,
        noteable_type: noteable_type,
        preview_markdown_endpoint: preview_markdown_endpoint,
        register_path: register_path,
        sign_in_path: sign_in_path,
        report_abuse_path: report_abuse_path,
        markdown_docs_path: markdown_docs_path,
        new_comment_template_paths: new_comment_template_paths
      }
    end

    def extra_prefetch_endpoints
      [discussions_endpoint]
    end
  end
end
