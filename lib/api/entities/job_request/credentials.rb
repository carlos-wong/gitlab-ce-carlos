# frozen_string_literal: true

module API
  module Entities
    module JobRequest
      class Credentials < Grape::Entity
        expose :type, :url, :username, :password
      end
    end
  end
end
