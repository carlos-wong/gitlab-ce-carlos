require 'prometheus/client'

# Keep separate directories for separate processes
def prometheus_default_multiproc_dir
  return unless Rails.env.development? || Rails.env.test?

  if Sidekiq.server?
    Rails.root.join('tmp/prometheus_multiproc_dir/sidekiq')
  elsif defined?(Unicorn::Worker)
    Rails.root.join('tmp/prometheus_multiproc_dir/unicorn')
  elsif defined?(::Puma)
    Rails.root.join('tmp/prometheus_multiproc_dir/puma')
  else
    Rails.root.join('tmp/prometheus_multiproc_dir')
  end
end

Prometheus::Client.configure do |config|
  config.logger = Rails.logger # rubocop:disable Gitlab/RailsLogger

  config.initial_mmap_file_size = 4 * 1024

  config.multiprocess_files_dir = ENV['prometheus_multiproc_dir'] || prometheus_default_multiproc_dir

  config.pid_provider = Prometheus::PidProvider.method(:worker_id)
end

Gitlab::Application.configure do |config|
  # 0 should be Sentry to catch errors in this middleware
  config.middleware.insert(1, Gitlab::Metrics::RequestsRackMiddleware)
end

Sidekiq.configure_server do |config|
  config.on(:startup) do
    # webserver metrics are cleaned up in config.ru: `warmup` block
    Prometheus::CleanupMultiprocDirService.new.execute

    Gitlab::Metrics::SidekiqMetricsExporter.instance.start
  end
end

if !Rails.env.test? && Gitlab::Metrics.prometheus_metrics_enabled?
  Gitlab::Cluster::LifecycleEvents.on_worker_start do
    defined?(::Prometheus::Client.reinitialize_on_pid_change) && Prometheus::Client.reinitialize_on_pid_change

    Gitlab::Metrics::Samplers::RubySampler.initialize_instance(Settings.monitoring.ruby_sampler_interval).start
  end

  Gitlab::Cluster::LifecycleEvents.on_master_start do
    ::Prometheus::Client.reinitialize_on_pid_change(force: true)

    if defined?(::Unicorn)
      Gitlab::Metrics::Samplers::UnicornSampler.instance(Settings.monitoring.unicorn_sampler_interval).start
    elsif defined?(::Puma)
      Gitlab::Metrics::Samplers::PumaSampler.instance(Settings.monitoring.puma_sampler_interval).start
    end
  end
end
