# frozen_string_literal: true

module Sidebars
  module Groups
    module Menus
      class PackagesRegistriesMenu < ::Sidebars::Menu
        override :configure_menu_items
        def configure_menu_items
          add_item(packages_registry_menu_item)
          add_item(container_registry_menu_item)
          add_item(harbor_registry__menu_item)
          add_item(dependency_proxy_menu_item)
          true
        end

        override :title
        def title
          _('Packages & Registries')
        end

        override :sprite_icon
        def sprite_icon
          'package'
        end

        private

        def packages_registry_menu_item
          return nil_menu_item(:packages_registry) unless context.group.packages_feature_enabled?

          ::Sidebars::MenuItem.new(
            title: _('Package Registry'),
            link: group_packages_path(context.group),
            active_routes: { controller: 'groups/packages' },
            item_id: :packages_registry
          )
        end

        def container_registry_menu_item
          if !::Gitlab.config.registry.enabled || !can?(context.current_user, :read_container_image, context.group)
            return nil_menu_item(:container_registry)
          end

          ::Sidebars::MenuItem.new(
            title: _('Container Registry'),
            link: group_container_registries_path(context.group),
            active_routes: { controller: 'groups/registry/repositories' },
            item_id: :container_registry
          )
        end

        def harbor_registry__menu_item
          return nil_menu_item(:harbor_registry) if Feature.disabled?(:harbor_registry_integration)

          ::Sidebars::MenuItem.new(
            title: _('Harbor Registry'),
            link: group_harbor_repositories_path(context.group),
            active_routes: { controller: 'groups/harbor/repositories' },
            item_id: :harbor_registry
          )
        end

        def dependency_proxy_menu_item
          setting_does_not_exist_or_is_enabled = !context.group.dependency_proxy_setting ||
                                                  context.group.dependency_proxy_setting.enabled

          return nil_menu_item(:dependency_proxy) unless can?(context.current_user, :read_dependency_proxy, context.group)
          return nil_menu_item(:dependency_proxy) unless setting_does_not_exist_or_is_enabled

          ::Sidebars::MenuItem.new(
            title: _('Dependency Proxy'),
            link: group_dependency_proxy_path(context.group),
            active_routes: { controller: 'groups/dependency_proxies' },
            item_id: :dependency_proxy
          )
        end

        def nil_menu_item(item_id)
          ::Sidebars::NilMenuItem.new(item_id: item_id)
        end
      end
    end
  end
end
