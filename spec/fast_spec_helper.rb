# frozen_string_literal: true

require 'bundler/setup'

ENV['GITLAB_ENV'] = 'test'
ENV['IN_MEMORY_APPLICATION_SETTINGS'] = 'true'

require 'active_support/dependencies'
require_relative '../config/initializers/0_inject_enterprise_edition_module'
require_relative '../config/settings'
require_relative 'support/rspec'
require 'active_support/all'

ActiveSupport::Dependencies.autoload_paths << 'lib'
ActiveSupport::Dependencies.autoload_paths << 'ee/lib'
ActiveSupport::XmlMini.backend = 'Nokogiri'
