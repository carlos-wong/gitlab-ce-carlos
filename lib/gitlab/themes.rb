# frozen_string_literal: true

module Gitlab
  # Module containing GitLab's application theme definitions and helper methods
  # for accessing them.
  module Themes
    extend self

    # Theme ID used when no `default_theme` configuration setting is provided.
    APPLICATION_DEFAULT = 1

    # Struct class representing a single Theme
    Theme = Struct.new(:id, :name, :css_class)

    # All available Themes
    THEMES = [
      Theme.new(1, 'Indigo', 'ui-indigo'),
      Theme.new(6, 'Light Indigo', 'ui-light-indigo'),
      Theme.new(4, 'Blue', 'ui-blue'),
      Theme.new(7, 'Light Blue', 'ui-light-blue'),
      Theme.new(5, 'Green', 'ui-green'),
      Theme.new(8, 'Light Green', 'ui-light-green'),
      Theme.new(9, 'Red', 'ui-red'),
      Theme.new(10, 'Light Red', 'ui-light-red'),
      Theme.new(2, 'Dark', 'ui-dark'),
      Theme.new(3, 'Light', 'ui-light')
    ].freeze

    # Convenience method to get a space-separated String of all the theme
    # classes that might be applied to the `body` element
    #
    # Returns a String
    def body_classes
      THEMES.collect(&:css_class).uniq.join(' ')
    end

    # Get a Theme by its ID
    #
    # If the ID is invalid, returns the default Theme.
    #
    # id - Integer ID
    #
    # Returns a Theme
    def by_id(id)
      THEMES.detect { |t| t.id == id } || default
    end

    # Returns the number of defined Themes
    def count
      THEMES.size
    end

    # Get the default Theme
    #
    # Returns a Theme
    def default
      by_id(default_id)
    end

    # Iterate through each Theme
    #
    # Yields the Theme object
    def each(&block)
      THEMES.each(&block)
    end

    # Get the Theme for the specified user, or the default
    #
    # user - User record
    #
    # Returns a Theme
    def for_user(user)
      if user
        by_id(user.theme_id)
      else
        default
      end
    end

    def self.valid_ids
      THEMES.map(&:id)
    end

    private

    def default_id
      @default_id ||= begin
        id = Gitlab.config.gitlab.default_theme.to_i
        theme_ids = THEMES.map(&:id)

        theme_ids.include?(id) ? id : APPLICATION_DEFAULT
      end
    end
  end
end
