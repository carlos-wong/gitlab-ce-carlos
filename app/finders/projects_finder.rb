# frozen_string_literal: true

# ProjectsFinder
#
# Used to filter Projects  by set of params
#
# Arguments:
#   current_user - which user use
#   project_ids_relation: int[] - project ids to use
#   params:
#     trending: boolean
#     owned: boolean
#     non_public: boolean
#     starred: boolean
#     sort: string
#     visibility_level: int
#     tag: string[] - deprecated, use 'topic' instead
#     topic: string[]
#     topic_id: int
#     personal: boolean
#     search: string
#     search_namespaces: boolean
#     minimum_search_length: int
#     non_archived: boolean
#     archived: 'only' or boolean
#     min_access_level: integer
#     last_activity_after: datetime
#     last_activity_before: datetime
#     repository_storage: string
#     without_deleted: boolean
#     not_aimed_for_deletion: boolean
#
class ProjectsFinder < UnionFinder
  include CustomAttributesFilter

  attr_accessor :params
  attr_reader :current_user, :project_ids_relation

  def initialize(params: {}, current_user: nil, project_ids_relation: nil)
    @params = params
    @current_user = current_user
    @project_ids_relation = project_ids_relation

    @params[:topic] ||= @params.delete(:tag) if @params[:tag].present?
  end

  def execute
    user = params.delete(:user)
    collection =
      if user
        PersonalProjectsFinder.new(user, finder_params).execute(current_user) # rubocop: disable CodeReuse/Finder
      else
        init_collection
      end

    use_cte = params.delete(:use_cte)
    collection = Project.wrap_with_cte(collection) if use_cte
    collection = filter_projects(collection)

    if params[:sort] == 'similarity' && params[:search]
      collection.sorted_by_similarity_desc(params[:search])
    else
      sort(collection)
    end
  end

  private

  def init_collection
    if current_user
      collection_with_user
    else
      collection_without_user
    end
  end

  # EE would override this to add more filters
  def filter_projects(collection)
    collection = by_ids(collection)
    collection = by_personal(collection)
    collection = by_starred(collection)
    collection = by_trending(collection)
    collection = by_visibility_level(collection)
    collection = by_topics(collection)
    collection = by_topic_id(collection)
    collection = by_search(collection)
    collection = by_archived(collection)
    collection = by_custom_attributes(collection)
    collection = by_deleted_status(collection)
    collection = by_not_aimed_for_deletion(collection)
    collection = by_last_activity_after(collection)
    collection = by_last_activity_before(collection)
    by_repository_storage(collection)
  end

  def collection_with_user
    if owned_projects?
      current_user.owned_projects
    elsif min_access_level?
      current_user.authorized_projects(params[:min_access_level])
    else
      if private_only? || impossible_visibility_level?
        current_user.authorized_projects
      else
        Project.public_or_visible_to_user(current_user)
      end
    end
  end

  # Builds a collection for an anonymous user.
  def collection_without_user
    if private_only? || owned_projects? || min_access_level?
      Project.none
    else
      Project.public_to_user
    end
  end

  # This is an optimization - surprisingly PostgreSQL does not optimize
  # for this.
  #
  # If the default visiblity level and desired visiblity level filter cancels
  # each other out, don't use the SQL clause for visibility level in
  # `Project.public_or_visible_to_user`. In fact, this then becames equivalent
  # to just authorized projects for the user.
  #
  # E.g.
  # (EXISTS(<authorized_projects>) OR projects.visibility_level IN (10,20))
  #   AND "projects"."visibility_level" = 0
  #
  # is essentially
  # EXISTS(<authorized_projects>) AND "projects"."visibility_level" = 0
  #
  # See https://gitlab.com/gitlab-org/gitlab/issues/37007
  def impossible_visibility_level?
    return unless params[:visibility_level].present?

    public_visibility_levels = Gitlab::VisibilityLevel.levels_for_user(current_user)

    !public_visibility_levels.include?(params[:visibility_level].to_i)
  end

  def owned_projects?
    params[:owned].present?
  end

  def private_only?
    params[:non_public].present?
  end

  def min_access_level?
    params[:min_access_level].present?
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def by_ids(items)
    items = items.where(id: project_ids_relation) if project_ids_relation
    items = items.where('projects.id > ?', params[:id_after]) if params[:id_after]
    items = items.where('projects.id < ?', params[:id_before]) if params[:id_before]
    items
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def union(items)
    find_union(items, Project).with_route
  end

  def by_personal(items)
    params[:personal].present? && current_user ? items.personal(current_user) : items
  end

  def by_starred(items)
    params[:starred].present? && current_user ? items.starred_by(current_user) : items
  end

  def by_trending(items)
    params[:trending].present? ? items.trending : items
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def by_visibility_level(items)
    params[:visibility_level].present? ? items.where(visibility_level: params[:visibility_level]) : items
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def by_topics(items)
    return items unless params[:topic].present?

    topics = params[:topic].instance_of?(String) ? params[:topic].split(',') : params[:topic]
    topics.map(&:strip).uniq.reject(&:empty?).each do |topic|
      items = items.with_topic_by_name(topic)
    end

    items
  end

  def by_topic_id(items)
    return items unless params[:topic_id].present?

    topic = Projects::Topic.find_by(id: params[:topic_id]) # rubocop: disable CodeReuse/ActiveRecord
    return Project.none unless topic

    items.with_topic(topic)
  end

  def by_search(items)
    params[:search] ||= params[:name]

    return items if Feature.enabled?(:disable_anonymous_project_search, type: :ops) && current_user.nil?
    return items.none if params[:search].present? && params[:minimum_search_length].present? && params[:search].length < params[:minimum_search_length].to_i

    items.optionally_search(params[:search], include_namespace: params[:search_namespaces].present?)
  end

  def by_deleted_status(items)
    params[:without_deleted].present? ? items.without_deleted : items
  end

  def by_not_aimed_for_deletion(items)
    params[:not_aimed_for_deletion].present? ? items.not_aimed_for_deletion : items
  end

  def by_last_activity_after(items)
    if params[:last_activity_after].present?
      items.where("last_activity_at > ?", params[:last_activity_after]) # rubocop: disable CodeReuse/ActiveRecord
    else
      items
    end
  end

  def by_last_activity_before(items)
    if params[:last_activity_before].present?
      items.where("last_activity_at < ?", params[:last_activity_before]) # rubocop: disable CodeReuse/ActiveRecord
    else
      items
    end
  end

  def by_repository_storage(items)
    if params[:repository_storage].present?
      items.where(repository_storage: params[:repository_storage]) # rubocop: disable CodeReuse/ActiveRecord
    else
      items
    end
  end

  def sort(items)
    if params[:sort].present?
      items.sort_by_attribute(params[:sort])
    else
      items.projects_order_id_desc
    end
  end

  def by_archived(projects)
    if params[:non_archived]
      projects.non_archived
    elsif params.key?(:archived)
      if params[:archived] == 'only'
        projects.archived
      elsif Gitlab::Utils.to_boolean(params[:archived])
        projects
      else
        projects.non_archived
      end
    else
      projects
    end
  end

  def finder_params
    return {} unless min_access_level?

    { min_access_level: params[:min_access_level] }
  end
end

ProjectsFinder.prepend_mod_with('ProjectsFinder')
