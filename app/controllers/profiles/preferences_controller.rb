# frozen_string_literal: true

class Profiles::PreferencesController < Profiles::ApplicationController
  before_action :user

  def show
  end

  def update
    begin
      result = Users::UpdateService.new(current_user, preferences_params.merge(user: user)).execute

      if result[:status] == :success
        flash[:notice] = 'Preferences saved.'
      else
        flash[:alert] = 'Failed to save preferences.'
      end
    rescue ArgumentError => e
      # Raised when `dashboard` is given an invalid value.
      flash[:alert] = "Failed to save preferences (#{e.message})."
    end

    respond_to do |format|
      format.html { redirect_to profile_preferences_path }
      format.js
    end
  end

  private

  def user
    @user = current_user
  end

  def preferences_params
    params.require(:user).permit(preferences_param_names)
  end

  def preferences_param_names
    [
      :color_scheme_id,
      :layout,
      :dashboard,
      :project_view,
      :theme_id,
      :first_day_of_week,
      :preferred_language
    ]
  end
end
