# frozen_string_literal: true

module Sidebars
  module Projects
    module Menus
      class PackagesRegistriesMenu < ::Sidebars::Menu
        override :configure_menu_items
        def configure_menu_items
          add_item(packages_registry_menu_item)
          add_item(container_registry_menu_item)
          add_item(infrastructure_registry_menu_item)
          add_item(harbor_registry__menu_item)
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
          if packages_registry_disabled?
            return ::Sidebars::NilMenuItem.new(item_id: :packages_registry)
          end

          ::Sidebars::MenuItem.new(
            title: _('Package Registry'),
            link: project_packages_path(context.project),
            active_routes: { controller: :packages },
            item_id: :packages_registry,
            container_html_options: { class: 'shortcuts-container-registry' }
          )
        end

        def container_registry_menu_item
          if !::Gitlab.config.registry.enabled || !can?(context.current_user, :read_container_image, context.project)
            return ::Sidebars::NilMenuItem.new(item_id: :container_registry)
          end

          ::Sidebars::MenuItem.new(
            title: _('Container Registry'),
            link: project_container_registry_index_path(context.project),
            active_routes: { controller: 'projects/registry/repositories' },
            item_id: :container_registry
          )
        end

        def infrastructure_registry_menu_item
          if packages_registry_disabled?
            return ::Sidebars::NilMenuItem.new(item_id: :infrastructure_registry)
          end

          ::Sidebars::MenuItem.new(
            title: _('Infrastructure Registry'),
            link: project_infrastructure_registry_index_path(context.project),
            active_routes: { controller: :infrastructure_registry },
            item_id: :infrastructure_registry
          )
        end

        def harbor_registry__menu_item
          return ::Sidebars::NilMenuItem.new(item_id: :harbor_registry) if Feature.disabled?(:harbor_registry_integration)

          ::Sidebars::MenuItem.new(
            title: _('Harbor Registry'),
            link: project_harbor_registry_index_path(context.project),
            active_routes: { controller: 'projects/harbor/repositories' },
            item_id: :harbor_registry
          )
        end

        def packages_registry_disabled?
          !::Gitlab.config.packages.enabled || !can?(context.current_user, :read_package, context.project)
        end
      end
    end
  end
end
