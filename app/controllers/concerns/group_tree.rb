# frozen_string_literal: true

module GroupTree
  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  # rubocop: disable CodeReuse/ActiveRecord
  def render_group_tree(groups)
    groups = groups.sort_by_attribute(@sort = params[:sort])

    groups = if params[:filter].present?
               filtered_groups_with_ancestors(groups)
             else
               # If `params[:parent_id]` is `nil`, we will only show root-groups
               groups.where(parent_id: params[:parent_id]).page(params[:page])
             end

    @groups = groups.with_selects_for_list(archived: params[:archived])

    respond_to do |format|
      format.html
      format.json do
        serializer = GroupChildSerializer.new(current_user: current_user)
                       .with_pagination(request, response)
        serializer.expand_hierarchy if params[:filter].present?
        render json: serializer.represent(@groups)
      end
    end
    # rubocop:enable Gitlab/ModuleWithInstanceVariables
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  def filtered_groups_with_ancestors(groups)
    filtered_groups = groups.search(params[:filter]).page(params[:page])

    if Group.supports_nested_objects?
      # We find the ancestors by ID of the search results here.
      # Otherwise the ancestors would also have filters applied,
      # which would cause them not to be preloaded.
      #
      # Pagination needs to be applied before loading the ancestors to
      # make sure ancestors are not cut off by pagination.
      Gitlab::ObjectHierarchy.new(Group.where(id: filtered_groups.select(:id)))
        .base_and_ancestors
    else
      filtered_groups
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
