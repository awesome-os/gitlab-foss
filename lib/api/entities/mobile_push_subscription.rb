# frozen_string_literal: true

module API
  module Entities
    class MobilePushSubscription < Grape::Entity
      expose :id, documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the subscription.' }
      expose :created_at,
        documentation: { type: 'DateTime', example: '2026-07-30T12:00:00.000Z',
                         desc: 'Date and time when the subscription was created.' }
      # `missing` is what makes the app send a key; it never sends one unasked.
      expose :content_key,
        documentation: { type: 'String', example: 'missing', values: %w[missing present],
                         desc: '`present` when a content key younger than 90 days is stored for this device, ' \
                           '`missing` otherwise.' } do |sub|
        sub.content_key_current? ? 'present' : 'missing'
      end
    end
  end
end
