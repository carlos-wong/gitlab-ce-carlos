# frozen_string_literal: true

module Prometheus
  module PidProvider
    extend self

    def worker_id
      if Sidekiq.server?
        'sidekiq'
      elsif defined?(Unicorn::Worker)
        unicorn_worker_id
      elsif defined?(::Puma)
        puma_worker_id
      else
        unknown_process_id
      end
    end

    private

    def unicorn_worker_id
      if matches = process_name.match(/unicorn.*worker\[([0-9]+)\]/)
        "unicorn_#{matches[1]}"
      elsif process_name =~ /unicorn/
        "unicorn_master"
      else
        unknown_process_id
      end
    end

    def puma_worker_id
      if matches = process_name.match(/puma.*cluster worker ([0-9]+):/)
        "puma_#{matches[1]}"
      elsif process_name =~ /puma/
        "puma_master"
      else
        unknown_process_id
      end
    end

    def unknown_process_id
      "process_#{Process.pid}"
    end

    def process_name
      $0
    end
  end
end
