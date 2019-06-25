# frozen_string_literal: true

class Profiles::GroupsController < Profiles::ApplicationController
  include RoutableActions

  def update
    group = find_routable!(Group, params[:id])
    notification_setting = current_user.notification_settings.find_by(source: group) # rubocop: disable CodeReuse/ActiveRecord

    if notification_setting.update(update_params)
      flash[:notice] = "Notification settings for #{group.name} saved"
    else
      flash[:alert] = "Failed to save new settings for #{group.name}"
    end

    redirect_back_or_default(default: profile_notifications_path)
  end

  private

  def update_params
    params.require(:notification_setting).permit(:notification_email)
  end
end
