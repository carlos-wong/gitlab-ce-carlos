# frozen_string_literal: true

puts "Creating the default ApplicationSetting record.".color(:green)
ApplicationSetting.create_from_defaults

# Details https://gitlab.com/gitlab-org/gitlab-ce/issues/46241
puts "Enable hashed storage for every new projects.".color(:green)
ApplicationSetting.current_without_cache.update!(hashed_storage_enabled: true)

print '.'
