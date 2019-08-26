# frozen_string_literal: true

module QA::Page
  module Search
    class Results < QA::Page::Base
      view 'app/views/search/_category.html.haml' do
        element :code_tab
      end

      view 'app/views/search/results/_blob_data.html.haml' do
        element :result_item_content
        element :file_title_content
        element :file_text_content
      end

      def switch_to_code
        click_element(:code_tab)
      end

      def has_file_in_project?(file_name, project_name)
        has_element? :result_item_content, text: "#{project_name}: #{file_name}"
      end

      def has_file_with_content?(file_name, file_text)
        within_element_by_index :result_item_content, 0 do
          false unless has_element? :file_title_content, text: file_name

          has_element? :file_text_content, text: file_text
        end
      end
    end
  end
end
