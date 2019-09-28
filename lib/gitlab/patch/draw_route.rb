# frozen_string_literal: true

# We're patching `ActionDispatch::Routing::Mapper` in
# config/initializers/routing_draw.rb
module Gitlab
  module Patch
    module DrawRoute
      prepend_if_ee('EE::Gitlab::Patch::DrawRoute') # rubocop: disable Cop/InjectEnterpriseEditionModule

      RoutesNotFound = Class.new(StandardError)

      def draw(routes_name)
        drawn_any = draw_ce(routes_name) | draw_ee(routes_name)

        drawn_any || raise(RoutesNotFound.new("Cannot find #{routes_name}"))
      end

      def draw_ce(routes_name)
        draw_route(route_path("config/routes/#{routes_name}.rb"))
      end

      def draw_ee(_)
        true
      end

      def route_path(routes_name)
        Rails.root.join(routes_name)
      end

      def draw_route(path)
        if File.exist?(path)
          instance_eval(File.read(path))
          true
        else
          false
        end
      end
    end
  end
end
