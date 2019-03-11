# frozen_string_literal: true

module Emails
  class BaseService
    attr_reader :current_user, :params, :user

    def initialize(current_user, params = {})
      @current_user = current_user
      @params = params.dup
      @user = params.delete(:user)
    end
  end
end
