# frozen_string_literal: true

class Admin::AppearancesController < Admin::ApplicationController
  before_action :set_appearance, except: :create

  def show
  end

  def preview_sign_in
    render 'preview_sign_in', layout: 'devise'
  end

  def create
    @appearance = Appearance.new(appearance_params)

    if @appearance.save
      redirect_to admin_appearances_path, notice: _('Appearance was successfully created.')
    else
      render action: 'show'
    end
  end

  def update
    if @appearance.update(appearance_params)
      redirect_to admin_appearances_path, notice: _('Appearance was successfully updated.')
    else
      render action: 'show'
    end
  end

  def logo
    @appearance.remove_logo!

    @appearance.save

    redirect_to admin_appearances_path, notice: _('Logo was successfully removed.')
  end

  def header_logos
    @appearance.remove_header_logo!
    @appearance.save

    redirect_to admin_appearances_path, notice: _('Header logo was successfully removed.')
  end

  def favicon
    @appearance.remove_favicon!
    @appearance.save

    redirect_to admin_appearances_path, notice: _('Favicon was successfully removed.')
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_appearance
    @appearance = Appearance.current || Appearance.new
  end

  # Only allow a trusted parameter "white list" through.
  def appearance_params
    params.require(:appearance).permit(allowed_appearance_params)
  end

  def allowed_appearance_params
    %i[
      title
      description
      logo
      logo_cache
      header_logo
      header_logo_cache
      favicon
      favicon_cache
      new_project_guidelines
      updated_by
      header_message
      footer_message
      message_background_color
      message_font_color
      email_header_and_footer_enabled
    ]
  end
end
