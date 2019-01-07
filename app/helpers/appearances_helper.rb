# frozen_string_literal: true

module AppearancesHelper
  def brand_title
    current_appearance&.title.presence || default_brand_title
  end

  def default_brand_title
    # This resides in a separate method so that EE can easily redefine it.
    'GitLab Community Edition'
  end

  def brand_image
    image_tag(current_appearance.logo_path) if current_appearance&.logo?
  end

  def brand_text
    markdown_field(current_appearance, :description)
  end

  def brand_new_project_guidelines
    markdown_field(current_appearance, :new_project_guidelines)
  end

  def current_appearance
    @appearance ||= Appearance.current
  end

  def brand_header_logo
    if current_appearance&.header_logo?
      image_tag current_appearance.header_logo_path
    else
      render 'shared/logo.svg'
    end
  end

  # Skip the 'GitLab' type logo when custom brand logo is set
  def brand_header_logo_type
    unless current_appearance&.header_logo?
      render 'shared/logo_type.svg'
    end
  end
end
