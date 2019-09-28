# frozen_string_literal: true

module Gitlab
  class OmniauthInitializer
    prepend_if_ee('::EE::Gitlab::OmniauthInitializer') # rubocop: disable Cop/InjectEnterpriseEditionModule

    def initialize(devise_config)
      @devise_config = devise_config
    end

    def execute(providers)
      providers.each do |provider|
        name = provider['name'].to_sym

        add_provider_to_devise(name, *arguments_for(provider))
        setup_provider(name)
      end
    end

    private

    def add_provider_to_devise(*args)
      @devise_config.omniauth(*args)
    end

    def arguments_for(provider)
      provider_arguments = []

      %w[app_id app_secret].each do |argument|
        provider_arguments << provider[argument] if provider[argument]
      end

      case provider['args']
      when Array
        # An Array from the configuration will be expanded.
        provider_arguments.concat provider['args']
      when Hash
        hash_arguments = provider['args'].merge(provider_defaults(provider))

        # A Hash from the configuration will be passed as is.
        provider_arguments << normalize_hash_arguments(hash_arguments)
      end

      provider_arguments
    end

    def normalize_hash_arguments(args)
      args.symbolize_keys!

      # Rails 5.1 deprecated the use of string names in the middleware
      # (https://github.com/rails/rails/commit/83b767ce), so we need to
      # pass in the actual class to Devise.
      if args[:strategy_class].is_a?(String)
        args[:strategy_class] = args[:strategy_class].constantize
      end

      # Providers that are known to depend on rack-oauth2, like those using
      # Omniauth::Strategies::OpenIDConnect, need to be quirked so the
      # client_auth_method argument value is passed as a symbol.
      if (args[:strategy_class] == OmniAuth::Strategies::OpenIDConnect ||
        args[:name] == 'openid_connect') &&
        args[:client_auth_method].is_a?(String)

        args[:client_auth_method] = args[:client_auth_method].to_sym
      end

      args
    end

    def provider_defaults(provider)
      case provider['name']
      when 'cas3'
        { on_single_sign_out: cas3_signout_handler }
      when 'authentiq'
        { remote_sign_out_handler: authentiq_signout_handler }
      when 'shibboleth'
        { fail_with_empty_uid: true }
      else
        {}
      end
    end

    def cas3_signout_handler
      lambda do |request|
        ticket = request.params[:session_index]
        raise "Service Ticket not found." unless Gitlab::Auth::OAuth::Session.valid?(:cas3, ticket)

        Gitlab::Auth::OAuth::Session.destroy(:cas3, ticket)
        true
      end
    end

    def authentiq_signout_handler
      lambda do |request|
        authentiq_session = request.params['sid']
        if Gitlab::Auth::OAuth::Session.valid?(:authentiq, authentiq_session)
          Gitlab::Auth::OAuth::Session.destroy(:authentiq, authentiq_session)
          true
        else
          false
        end
      end
    end

    def omniauth_customized_providers
      @omniauth_customized_providers ||= build_omniauth_customized_providers
    end

    # We override this in EE
    def build_omniauth_customized_providers
      %i[bitbucket jwt]
    end

    def setup_provider(provider)
      case provider
      when :kerberos
        require 'omniauth-kerberos'
      when *omniauth_customized_providers
        require_dependency "omni_auth/strategies/#{provider}"
      end
    end
  end
end
