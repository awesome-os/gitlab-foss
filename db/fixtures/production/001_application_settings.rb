# frozen_string_literal: true

puts Rainbow("Creating the default ApplicationSetting record.").green
Gitlab::CurrentSettings.writable_application_settings
