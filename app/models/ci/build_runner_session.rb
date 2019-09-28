# frozen_string_literal: true

module Ci
  # The purpose of this class is to store Build related runner session.
  # Data will be removed after transitioning from running to any state.
  class BuildRunnerSession < ApplicationRecord
    extend Gitlab::Ci::Model

    TERMINAL_SUBPROTOCOL = 'terminal.gitlab.com'

    self.table_name = 'ci_builds_runner_session'

    belongs_to :build, class_name: 'Ci::Build', inverse_of: :runner_session

    validates :build, presence: true
    validates :url, addressable_url: { schemes: %w(https) }

    def terminal_specification
      wss_url = Gitlab::UrlHelpers.as_wss(self.url)
      return {} unless wss_url.present?

      wss_url = "#{wss_url}/exec"
      channel_specification(wss_url, TERMINAL_SUBPROTOCOL)
    end

    private

    def channel_specification(url, subprotocol)
      return {} if subprotocol.blank? || url.blank?

      {
        subprotocols: Array(subprotocol),
        url: url,
        headers: { Authorization: [authorization.presence] }.compact,
        ca_pem: certificate.presence
      }
    end
  end
end

Ci::BuildRunnerSession.prepend_if_ee('EE::Ci::BuildRunnerSession')
