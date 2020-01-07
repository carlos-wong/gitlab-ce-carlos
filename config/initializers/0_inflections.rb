# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format
# (all these examples are active by default):
# ActiveSupport::Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end
#
ActiveSupport::Inflector.inflections do |inflect|
  inflect.uncountable %w(
    award_emoji
    container_repository_registry
    design_registry
    event_log
    file_registry
    group_view
    job_artifact_registry
    lfs_object_registry
    project_auto_devops
    project_registry
    project_statistics
    system_note_metadata
    vulnerabilities_feedback
    vulnerability_feedback
  )
  inflect.acronym 'EE'
end
