# frozen_string_literal: true

module NavbarStructureHelper
  def insert_after_nav_item(before_nav_item_name, new_nav_item:)
    expect(structure).to include(a_hash_including(nav_item: before_nav_item_name))

    index = structure.find_index { |h| h[:nav_item] == before_nav_item_name if h }
    structure.insert(index + 1, new_nav_item)
  end

  def insert_after_sub_nav_item(before_sub_nav_item_name, within:, new_sub_nav_item_name:)
    expect(structure).to include(a_hash_including(nav_item: within))
    hash = structure.find { |h| h[:nav_item] == within if h }

    expect(hash).to have_key(:nav_sub_items)
    expect(hash[:nav_sub_items]).to include(before_sub_nav_item_name)

    index = hash[:nav_sub_items].find_index(before_sub_nav_item_name)
    hash[:nav_sub_items].insert(index + 1, new_sub_nav_item_name)
  end

  def insert_before_sub_nav_item(after_sub_nav_item_name, within:, new_sub_nav_item_name:)
    expect(structure).to include(a_hash_including(nav_item: within))
    hash = structure.find { |h| h[:nav_item] == within if h }

    expect(hash).to have_key(:nav_sub_items)
    expect(hash[:nav_sub_items]).to include(after_sub_nav_item_name)

    index = hash[:nav_sub_items].find_index(after_sub_nav_item_name)
    hash[:nav_sub_items].insert(index, new_sub_nav_item_name)
  end

  def insert_package_nav(within)
    insert_after_nav_item(
      within,
      new_nav_item: {
        nav_item: _('Packages & Registries'),
        nav_sub_items: [_('Package Registry')]
      }
    )
  end

  def insert_customer_relations_nav(within)
    insert_after_nav_item(
      within,
      new_nav_item: {
        nav_item: _('Customer relations'),
        nav_sub_items: [
          _('Contacts'),
          _('Organizations')
        ]
      }
    )
  end

  def insert_container_nav
    insert_after_sub_nav_item(
      _('Package Registry'),
      within: _('Packages & Registries'),
      new_sub_nav_item_name: _('Container Registry')
    )
  end

  def insert_dependency_proxy_nav
    insert_after_sub_nav_item(
      _('Package Registry'),
      within: _('Packages & Registries'),
      new_sub_nav_item_name: _('Dependency Proxy')
    )
  end

  def insert_infrastructure_registry_nav
    insert_after_sub_nav_item(
      _('Package Registry'),
      within: _('Packages & Registries'),
      new_sub_nav_item_name: _('Infrastructure Registry')
    )
  end

  def insert_harbor_registry_nav(within)
    insert_after_sub_nav_item(
      within,
      within: _('Packages & Registries'),
      new_sub_nav_item_name: _('Harbor Registry')
    )
  end

  def insert_infrastructure_google_cloud_nav
    insert_after_sub_nav_item(
      _('Terraform'),
      within: _('Infrastructure'),
      new_sub_nav_item_name: _('Google Cloud')
    )
  end

  def analytics_sub_nav_item
    [
      _('Value stream'),
      _('CI/CD'),
      (_('Code review') if Gitlab.ee?),
      (_('Merge request') if Gitlab.ee?),
      _('Repository')
    ]
  end
end

NavbarStructureHelper.prepend_mod
