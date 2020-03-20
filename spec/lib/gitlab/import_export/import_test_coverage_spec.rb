# frozen_string_literal: true

require 'spec_helper'

# We want to test Import on "complete" data set,
# which means that every relation (as in our Import/Export definition) is covered.
# Fixture JSONs we use for testing Import such as
# `spec/fixtures/lib/gitlab/import_export/complex/project.json`
# should include these relations being non-empty.
describe 'Test coverage of the Project Import' do
  include ConfigurationHelper

  # `MUTED_RELATIONS` is a technical debt.
  # This list expected to be empty or used as a workround
  # in case this spec blocks an important urgent MR.
  # It is also expected that adding a relation in the list should lead to
  # opening a follow-up issue to fix this.
  MUTED_RELATIONS = %w[
    project.milestones.events.push_event_payload
    project.issues.events
    project.issues.events.push_event_payload
    project.issues.notes.events
    project.issues.notes.events.push_event_payload
    project.issues.milestone.events.push_event_payload
    project.issues.issue_milestones
    project.issues.issue_milestones.milestone
    project.issues.resource_label_events.label.priorities
    project.issues.designs.notes
    project.issues.designs.notes.author
    project.issues.designs.notes.events
    project.issues.designs.notes.events.push_event_payload
    project.merge_requests.metrics
    project.merge_requests.notes.events.push_event_payload
    project.merge_requests.events.push_event_payload
    project.merge_requests.timelogs
    project.merge_requests.label_links
    project.merge_requests.label_links.label
    project.merge_requests.label_links.label.priorities
    project.merge_requests.milestone
    project.merge_requests.milestone.events
    project.merge_requests.milestone.events.push_event_payload
    project.merge_requests.merge_request_milestones
    project.merge_requests.merge_request_milestones.milestone
    project.merge_requests.resource_label_events.label
    project.merge_requests.resource_label_events.label.priorities
    project.ci_pipelines.notes.events
    project.ci_pipelines.notes.events.push_event_payload
    project.protected_branches.unprotect_access_levels
    project.prometheus_metrics
    project.metrics_setting
    project.boards.lists.label.priorities
    project.service_desk_setting
  ].freeze

  # A list of JSON fixture files we use to test Import.
  # Note that we use separate fixture to test ee-only features.
  # Most of the relations are present in `complex/project.json`
  # which is our main fixture.
  PROJECT_JSON_FIXTURES_EE =
    if Gitlab.ee?
      ['ee/spec/fixtures/lib/gitlab/import_export/designs/project.json'].freeze
    else
      []
    end

  PROJECT_JSON_FIXTURES = [
    'spec/fixtures/lib/gitlab/import_export/complex/project.json',
    'spec/fixtures/lib/gitlab/import_export/group/project.json',
    'spec/fixtures/lib/gitlab/import_export/light/project.json',
    'spec/fixtures/lib/gitlab/import_export/milestone-iid/project.json'
  ].freeze + PROJECT_JSON_FIXTURES_EE

  it 'ensures that all imported/exported relations are present in test JSONs' do
    not_tested_relations = (relations_from_config - tested_relations) - MUTED_RELATIONS

    expect(not_tested_relations).to be_empty, failure_message(not_tested_relations)
  end

  def relations_from_config
    relation_paths_for(:project)
      .map { |relation_names| relation_names.join(".") }
      .to_set
  end

  def tested_relations
    PROJECT_JSON_FIXTURES.flat_map(&method(:relations_from_json)).to_set
  end

  def relations_from_json(json_file)
    json = ActiveSupport::JSON.decode(IO.read(json_file))

    Gitlab::ImportExport::RelationRenameService.rename(json)

    [].tap {|res| gather_relations({ project: json }, res, [])}
      .map {|relation_names| relation_names.join('.')}
  end

  def gather_relations(item, res, path)
    case item
    when Hash
      item.each do |k, v|
        if (v.is_a?(Array) || v.is_a?(Hash)) && v.present?
          new_path = path + [k]
          res << new_path
          gather_relations(v, res, new_path)
        end
      end
    when Array
      item.each {|i| gather_relations(i, res, path)}
    end
  end

  def failure_message(not_tested_relations)
    <<~MSG
      These relations seem to be added recenty and
      they expected to be covered in our Import specs: #{not_tested_relations}.

      To do that, expand one of the files listed in `PROJECT_JSON_FIXTURES`
      (or expand the list if you consider adding a new fixture file).

      After that, add a new spec into
      `spec/lib/gitlab/import_export/project_tree_restorer_spec.rb`
      to check that the relation is being imported correctly.

      In case the spec breaks the master or there is a sense of urgency,
      you could include the relations into the `MUTED_RELATIONS` list.

      Muting relations is considered to be a temporary solution, so please
      open a follow-up issue and try to fix that when it is possible.
    MSG
  end
end
