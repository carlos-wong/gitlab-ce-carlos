# frozen_string_literal: true

class Projects::GroupLinksController < Projects::ApplicationController
  layout 'project_settings'
  before_action :authorize_admin_project!
  before_action :authorize_admin_project_member!, only: [:update]

  def index
    redirect_to namespace_project_settings_members_path
  end

  def create
    group = Group.find(params[:link_group_id]) if params[:link_group_id].present?

    if group
      result = Projects::GroupLinks::CreateService.new(project, current_user, group_link_create_params).execute(group)
      return render_404 if result[:http_status] == 404

      flash[:alert] = result[:message] if result[:http_status] == 409
    else
      flash[:alert] = _('Please select a group.')
    end

    redirect_to project_project_members_path(project)
  end

  def update
    @group_link = @project.project_group_links.find(params[:id])

    @group_link.update(group_link_params)
  end

  def destroy
    group_link = project.project_group_links.find(params[:id])

    ::Projects::GroupLinks::DestroyService.new(project, current_user).execute(group_link)

    respond_to do |format|
      format.html do
        redirect_to project_project_members_path(project), status: :found
      end
      format.js { head :ok }
    end
  end

  protected

  def group_link_params
    params.require(:group_link).permit(:group_access, :expires_at)
  end

  def group_link_create_params
    params.permit(:link_group_access, :expires_at)
  end
end

Projects::GroupLinksController.prepend_if_ee('EE::Projects::GroupLinksController')
