# frozen_string_literal: true

RSpec.shared_context 'with a 1 MB markdown upload byte budget' do
  before do
    stub_application_setting(markdown_upload_limit_megabytes_per_day: 1)
  end

  def spend_markdown_upload_bytes(bytes, scope:)
    Gitlab::ApplicationRateLimiter.throttled?(:markdown_upload_bytes, scope: scope, cost: bytes)
  end
end
