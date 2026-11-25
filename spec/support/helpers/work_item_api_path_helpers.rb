# frozen_string_literal: true

module WorkItemApiPathHelpers
  # @note Raises instead of returning the path unchanged, which would make the
  #   example request the real work item and pass or fail for the wrong reason.
  def work_item_path_with_iid(path, from:, to: non_existing_record_iid)
    segment = "/-/work_items/#{from}/"
    raise ArgumentError, "#{path} has no #{segment} segment" unless path.include?(segment)

    path.sub(segment, "/-/work_items/#{to}/")
  end
end

RSpec.configure do |config|
  config.include WorkItemApiPathHelpers, :api
end
