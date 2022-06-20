# frozen_string_literal: true

module Ci
  module RunnersHelper
    include IconsHelper

    def runner_status_icon(runner, size: 16, icon_class: '')
      status = runner.status
      contacted_at = runner.contacted_at

      title = ''
      icon = 'warning-solid'
      span_class = ''

      case status
      when :online
        title = s_("Runners|Runner is online; last contact was %{runner_contact} ago") % { runner_contact: time_ago_in_words(contacted_at) }
        icon = 'status-active'
        span_class = 'gl-text-green-500'
      when :not_connected, :never_contacted
        title = s_("Runners|Runner has never contacted this instance")
        icon = 'warning-solid'
      when :offline
        title = s_("Runners|Runner is offline; last contact was %{runner_contact} ago") % { runner_contact: time_ago_in_words(contacted_at) }
        icon = 'status-failed'
        span_class = 'gl-text-red-500'
      when :stale
        # runner may have contacted (or not) and be stale: consider both cases.
        title = contacted_at ? s_("Runners|Runner is stale; last contact was %{runner_contact} ago") % { runner_contact: time_ago_in_words(contacted_at) } : s_("Runners|Runner is stale; it has never contacted this instance")
        icon = 'warning-solid'
      end

      content_tag(:span, class: span_class, title: title, data: { toggle: 'tooltip', container: 'body', testid: 'runner_status_icon', qa_selector: "runner_status_#{status}_content" }) do
        sprite_icon(icon, size: size, css_class: icon_class)
      end
    end

    def runner_link(runner)
      display_name = truncate(runner.display_name, length: 15)
      id = "\##{runner.id}"

      if current_user && current_user.admin
        link_to admin_runner_path(runner) do
          display_name + id
        end
      else
        display_name + id
      end
    end

    # Due to inability of performing sorting of runners by cached "contacted_at" values we have to show uncached values if sorting by "contacted_asc" is requested.
    # Please refer to the following issue for more details: https://gitlab.com/gitlab-org/gitlab-foss/issues/55920
    def runner_contacted_at(runner)
      if params[:sort] == 'contacted_asc'
        runner.uncached_contacted_at
      else
        runner.contacted_at
      end
    end

    def admin_runners_data_attributes
      {
        # Runner install help page is external, located at
        # https://gitlab.com/gitlab-org/gitlab-runner
        runner_install_help_page: 'https://docs.gitlab.com/runner/install/',
        registration_token: Gitlab::CurrentSettings.runners_registration_token,
        online_contact_timeout_secs: ::Ci::Runner::ONLINE_CONTACT_TIMEOUT.to_i,
        stale_timeout_secs: ::Ci::Runner::STALE_TIMEOUT.to_i
      }
    end

    def group_shared_runners_settings_data(group)
      {
        update_path: api_v4_groups_path(id: group.id),
        shared_runners_availability: group.shared_runners_setting,
        parent_shared_runners_availability: group.parent&.shared_runners_setting,
        runner_enabled: Namespace::SR_ENABLED,
        runner_disabled: Namespace::SR_DISABLED_AND_UNOVERRIDABLE,
        runner_allow_override: Namespace::SR_DISABLED_WITH_OVERRIDE
      }
    end

    def group_runners_data_attributes(group)
      {
        registration_token: group.runners_token,
        group_id: group.id,
        group_full_path: group.full_path,
        runner_install_help_page: 'https://docs.gitlab.com/runner/install/',
        online_contact_timeout_secs: ::Ci::Runner::ONLINE_CONTACT_TIMEOUT.to_i,
        stale_timeout_secs: ::Ci::Runner::STALE_TIMEOUT.to_i
      }
    end

    def toggle_shared_runners_settings_data(project)
      {
        is_enabled: "#{project.shared_runners_enabled?}",
        is_disabled_and_unoverridable: "#{project.group&.shared_runners_setting == Namespace::SR_DISABLED_AND_UNOVERRIDABLE}",
        update_path: toggle_shared_runners_project_runners_path(project)
      }
    end
  end
end

Ci::RunnersHelper.prepend_mod_with('Ci::RunnersHelper')
