# frozen_string_literal: true

FactoryBot.define do
  factory :abuse_user_metadata, class: '::AntiAbuse::UserMetadata' do
    user
  end
end
