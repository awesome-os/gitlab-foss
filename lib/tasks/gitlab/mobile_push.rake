# frozen_string_literal: true

namespace :gitlab do
  namespace :mobile_push do
    desc 'GitLab | Mobile push | Clear the stored content keys so devices register new ones'
    task :clear_content_keys, [:username] => :environment do |_, args|
      user = nil

      if args[:username].present?
        user = User.find_by_username(args[:username])
        abort("Unable to find user with username #{args[:username]}.") unless user
      end

      cleared = Notifications::MobileDevicePushSubscription.clear_content_keys(user: user)

      puts "Cleared the content key of #{cleared} push subscription(s)."
    end
  end
end
