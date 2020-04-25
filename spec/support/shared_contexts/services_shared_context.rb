# frozen_string_literal: true

Service.available_services_names.each do |service|
  RSpec.shared_context service do
    let(:dashed_service) { service.dasherize }
    let(:service_method) { "#{service}_service".to_sym }
    let(:service_klass) { "#{service}_service".classify.constantize }
    let(:service_instance) { service_klass.new }
    let(:service_fields) { service_instance.fields }
    let(:service_attrs_list) { service_fields.inject([]) {|arr, hash| arr << hash[:name].to_sym } }
    let(:service_attrs) do
      service_attrs_list.inject({}) do |hash, k|
        if k =~ /^(token*|.*_token|.*_key)/
          hash.merge!(k => 'secrettoken')
        elsif k =~ /^(.*_url|url|webhook)/
          hash.merge!(k => "http://example.com")
        elsif service_klass.method_defined?("#{k}?")
          hash.merge!(k => true)
        elsif service == 'irker' && k == :recipients
          hash.merge!(k => 'irc://irc.network.net:666/#channel')
        elsif service == 'irker' && k == :server_port
          hash.merge!(k => 1234)
        elsif service == 'jira' && k == :jira_issue_transition_id
          hash.merge!(k => '1,2,3')
        else
          hash.merge!(k => "someword")
        end
      end
    end

    let(:licensed_features) do
      {
        'github' => :github_project_service_integration,
        'jenkins' => :jenkins_integration,
        'jenkins_deprecated' => :jenkins_integration
      }
    end

    before do
      enable_license_for_service(service)
    end

    def initialize_service(service)
      service_item = project.find_or_initialize_service(service)
      service_item.properties = service_attrs
      service_item.save!
      service_item
    end

    private

    def enable_license_for_service(service)
      return unless respond_to?(:stub_licensed_features)

      licensed_feature = licensed_features[service]
      return unless licensed_feature

      stub_licensed_features(licensed_feature => true)
      project.clear_memoization(:disabled_services)
      project.clear_memoization(:licensed_feature_available)
    end
  end
end
