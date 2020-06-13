# frozen_string_literal: true

FactoryBot.define do
  factory :clusters_applications_helm, class: 'Clusters::Applications::Helm' do
    cluster factory: %i(cluster provided_by_gcp)

    before(:create) do
      allow(Gitlab::Kubernetes::Helm::Certificate).to receive(:generate_root)
        .and_return(
          double(
            key_string: File.read(Rails.root.join('spec/fixtures/clusters/sample_key.key')),
            cert_string: File.read(Rails.root.join('spec/fixtures/clusters/sample_cert.pem'))
          )
        )
    end

    after(:create) do
      allow(Gitlab::Kubernetes::Helm::Certificate).to receive(:generate_root).and_call_original
    end

    trait :not_installable do
      status { -2 }
    end

    trait :errored do
      status { -1 }
      status_reason { 'something went wrong' }
    end

    trait :installable do
      status { 0 }
    end

    trait :scheduled do
      status { 1 }
    end

    trait :installing do
      status { 2 }
    end

    trait :installed do
      status { 3 }
    end

    trait :updating do
      status { 4 }
    end

    trait :updated do
      status { 5 }
    end

    trait :update_errored do
      status { 6 }
      status_reason { 'something went wrong' }
    end

    trait :uninstalling do
      status { 7 }
    end

    trait :uninstall_errored do
      status { 8 }
      status_reason { 'something went wrong' }
    end

    trait :timed_out do
      installing
      updated_at { ClusterWaitForAppInstallationWorker::TIMEOUT.ago }
    end

    factory :clusters_applications_ingress, class: 'Clusters::Applications::Ingress' do
      modsecurity_enabled { false }
      cluster factory: %i(cluster with_installed_helm provided_by_gcp)

      trait :no_helm_installed do
        cluster factory: %i(cluster provided_by_gcp)
      end
    end

    factory :clusters_applications_cert_manager, class: 'Clusters::Applications::CertManager' do
      email { 'admin@example.com' }
      cluster factory: %i(cluster with_installed_helm provided_by_gcp)

      trait :no_helm_installed do
        cluster factory: %i(cluster provided_by_gcp)
      end
    end

    factory :clusters_applications_elastic_stack, class: 'Clusters::Applications::ElasticStack' do
      cluster factory: %i(cluster with_installed_helm provided_by_gcp)

      trait :no_helm_installed do
        cluster factory: %i(cluster provided_by_gcp)
      end
    end

    factory :clusters_applications_crossplane, class: 'Clusters::Applications::Crossplane' do
      stack { 'gcp' }
      cluster factory: %i(cluster with_installed_helm provided_by_gcp)

      trait :no_helm_installed do
        cluster factory: %i(cluster provided_by_gcp)
      end
    end

    factory :clusters_applications_prometheus, class: 'Clusters::Applications::Prometheus' do
      cluster factory: %i(cluster with_installed_helm provided_by_gcp)

      trait :no_helm_installed do
        cluster factory: %i(cluster provided_by_gcp)
      end
    end

    factory :clusters_applications_runner, class: 'Clusters::Applications::Runner' do
      runner factory: %i(ci_runner)
      cluster factory: %i(cluster with_installed_helm provided_by_gcp)

      trait :no_helm_installed do
        cluster factory: %i(cluster provided_by_gcp)
      end
    end

    factory :clusters_applications_knative, class: 'Clusters::Applications::Knative' do
      hostname { 'example.com' }
      cluster factory: %i(cluster with_installed_helm provided_by_gcp)

      trait :no_helm_installed do
        cluster factory: %i(cluster provided_by_gcp)
      end
    end

    factory :clusters_applications_jupyter, class: 'Clusters::Applications::Jupyter' do
      oauth_application factory: :oauth_application
      cluster factory: %i(cluster with_installed_helm provided_by_gcp project)

      trait :no_helm_installed do
        cluster factory: %i(cluster provided_by_gcp)
      end
    end
  end
end
