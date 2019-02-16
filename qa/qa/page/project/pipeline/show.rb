module QA::Page
  module Project::Pipeline
    class Show < QA::Page::Base
      view 'app/assets/javascripts/vue_shared/components/header_ci_component.vue' do
        element :pipeline_header, /header class.*ci-header-container.*/ # rubocop:disable QA/ElementWithPattern
      end

      view 'app/assets/javascripts/pipelines/components/graph/graph_component.vue' do
        element :pipeline_graph, /class.*pipeline-graph.*/ # rubocop:disable QA/ElementWithPattern
      end

      view 'app/assets/javascripts/pipelines/components/graph/job_item.vue' do
        element :job_component, /class.*ci-job-component.*/ # rubocop:disable QA/ElementWithPattern
        element :job_link
      end

      view 'app/assets/javascripts/vue_shared/components/ci_icon.vue' do
        element :status_icon, 'ci-status-icon-${status}' # rubocop:disable QA/ElementWithPattern
      end

      def running?
        within('.ci-header-container') do
          page.has_content?('running')
        end
      end

      def has_build?(name, status: :success, wait: nil)
        within('.pipeline-graph') do
          within('.ci-job-component', text: name) do
            has_selector?(".ci-status-icon-#{status}", { wait: wait }.compact)
          end
        end
      end

      def go_to_job(job_name)
        find_element(:job_link, job_name).click
      end

      def go_to_first_job
        css = '.js-pipeline-graph-job-link'

        wait(reload: false) do
          has_css?(css)
        end

        first(css).click
      end
    end
  end
end
