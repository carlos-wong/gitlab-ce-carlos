module QA
  module Page
    module Dashboard
      class Projects < Page::Base
        view 'app/views/shared/projects/_search_form.html.haml' do
          element :form_filter_by_name, /form_tag.+id: 'project-filter-form'/ # rubocop:disable QA/ElementWithPattern
        end

        def go_to_project(name)
          filter_by_name(name)

          find_link(text: name).click
        end

        private

        def filter_by_name(name)
          page.within('form#project-filter-form') do
            fill_in :name, with: name
          end
        end
      end
    end
  end
end
