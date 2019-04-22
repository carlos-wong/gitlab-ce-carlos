# frozen_string_literal: true

module QA
  module Resource
    class Group < Base
      attr_accessor :path, :description

      attribute :sandbox do
        Sandbox.fabricate!
      end

      attribute :id

      def initialize
        @path = Runtime::Namespace.name
        @description = "QA test run at #{Runtime::Namespace.time}"
      end

      def fabricate!
        sandbox.visit!

        Page::Group::Show.perform do |group_show|
          if group_show.has_subgroup?(path)
            group_show.click_subgroup(path)
          else
            group_show.go_to_new_subgroup

            Page::Group::New.perform do |group_new|
              group_new.set_path(path)
              group_new.set_description(description)
              group_new.set_visibility('Public')
              group_new.create
            end

            # Ensure that the group was actually created
            group_show.wait(interval: 1) do
              group_show.has_text?(path) &&
                group_show.has_new_project_or_subgroup_dropdown?
            end
          end
        end
      end

      def fabricate_via_api!
        resource_web_url(api_get)
      rescue ResourceNotFoundError
        super
      end

      def api_get_path
        "/groups/#{CGI.escape("#{sandbox.path}/#{path}")}"
      end

      def api_members_path
        "#{api_get_path}/members"
      end

      def api_post_path
        '/groups'
      end

      def api_post_body
        {
          parent_id: sandbox.id,
          path: path,
          name: path,
          visibility: 'public'
        }
      end
    end
  end
end
