# frozen_string_literal: true

class Ldap::OmniauthCallbacksController < OmniauthCallbacksController
  extend ::Gitlab::Utils::Override

  def self.define_providers!
    return unless Gitlab::Auth::LDAP::Config.sign_in_enabled?

    Gitlab::Auth::LDAP::Config.available_servers.each do |server|
      alias_method server['provider_name'], :ldap
    end
  end

  # We only find ourselves here
  # if the authentication to LDAP was successful.
  def ldap
    return unless Gitlab::Auth::LDAP::Config.sign_in_enabled?

    sign_in_user_flow(Gitlab::Auth::LDAP::User)
  end

  define_providers!

  override :set_remember_me
  def set_remember_me(user)
    user.remember_me = params[:remember_me] if user.persisted?
  end

  override :fail_login
  def fail_login(user)
    flash[:alert] = _('Access denied for your LDAP account.')

    redirect_to new_user_session_path
  end
end

Ldap::OmniauthCallbacksController.prepend_if_ee('EE::Ldap::OmniauthCallbacksController')
