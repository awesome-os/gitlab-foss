# frozen_string_literal: true

FactoryBot.define do
  factory :oauth_application, class: 'Authn::OauthApplication', aliases: [:application] do
    sequence(:name) { |n| "OAuth App #{n}" }
    uid { Doorkeeper::OAuth::Helpers::UniqueToken.generate }
    redirect_uri { generate(:url) }
    owner
    owner_type { 'User' }
    organization { association(:common_organization) }
    device_code_enabled { false }
  end

  trait :group_owned do
    # Group-owned applications are persisted with the polymorphic base class
    # name, matching what Rails stores when the owner is assigned through
    # Group#oauth_applications.
    owner_type { 'Namespace' }
    owner { association(:group) }
  end

  trait :dynamic do
    owner { nil }
    owner_type { nil }
    dynamic { true }
  end

  trait :without_owner do
    owner { nil }
    owner_type { nil }
    dynamic { false }
  end

  trait :with_device_code_enabled do
    device_code_enabled { true }
  end

  trait :granular do
    transient do
      boundary { Authz::Boundary.for(:instance) }
      permissions { [:create_member_role] }
    end

    oauth_application_granular_scopes do
      granular_scope = association(:granular_scope,
        boundary: boundary, permissions: Array(permissions), strategy: :build)

      [association(:oauth_application_granular_scope,
        application: instance, granular_scope: granular_scope, strategy: :build)]
    end
  end
end
