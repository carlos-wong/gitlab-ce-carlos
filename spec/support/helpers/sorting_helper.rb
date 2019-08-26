# frozen_string_literal: true

# Helper allows you to sort items
#
# Params
#   value - value for sorting
#
# Usage:
#   include SortingHelper
#
#   sorting_by('Oldest updated')
#
module SortingHelper
  def sorting_by(value)
    find('.filter-dropdown-container button.dropdown-menu-toggle').click
    page.within('.content ul.dropdown-menu.dropdown-menu-right li') do
      click_link value
    end
  end
end
