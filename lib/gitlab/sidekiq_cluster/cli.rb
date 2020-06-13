# frozen_string_literal: true

require 'optparse'
require 'logger'
require 'time'

module Gitlab
  module SidekiqCluster
    class CLI
      CHECK_TERMINATE_INTERVAL_SECONDS = 1
      # How long to wait in total when asking for a clean termination
      # Sidekiq default to self-terminate is 25s
      TERMINATE_TIMEOUT_SECONDS = 30

      CommandError = Class.new(StandardError)

      def initialize(log_output = STDERR)
        require_relative '../../../lib/gitlab/sidekiq_logging/json_formatter'

        # As recommended by https://github.com/mperham/sidekiq/wiki/Advanced-Options#concurrency
        @max_concurrency = 50
        @min_concurrency = 0
        @environment = ENV['RAILS_ENV'] || 'development'
        @pid = nil
        @interval = 5
        @alive = true
        @processes = []
        @logger = Logger.new(log_output)
        @logger.formatter = ::Gitlab::SidekiqLogging::JSONFormatter.new
        @rails_path = Dir.pwd
        @dryrun = false
      end

      def run(argv = ARGV)
        if argv.empty?
          raise CommandError,
            'You must specify at least one queue to start a worker for'
        end

        option_parser.parse!(argv)

        all_queues = SidekiqConfig::CliMethods.all_queues(@rails_path)
        queue_names = SidekiqConfig::CliMethods.worker_queues(@rails_path)

        queue_groups = argv.map do |queues|
          next queue_names if queues == '*'

          # When using the experimental queue query syntax, we treat
          # each queue group as a worker attribute query, and resolve
          # the queues for the queue group using this query.
          if @experimental_queue_selector
            SidekiqConfig::CliMethods.query_workers(queues, all_queues)
          else
            SidekiqConfig::CliMethods.expand_queues(queues.split(','), queue_names)
          end
        end

        if @negate_queues
          queue_groups.map! { |queues| queue_names - queues }
        end

        if queue_groups.all?(&:empty?)
          raise CommandError,
            'No queues found, you must select at least one queue'
        end

        @logger.info("Starting cluster with #{queue_groups.length} processes")

        @processes = SidekiqCluster.start(
          queue_groups,
          env: @environment,
          directory: @rails_path,
          max_concurrency: @max_concurrency,
          min_concurrency: @min_concurrency,
          dryrun: @dryrun
        )

        return if @dryrun

        write_pid
        trap_signals
        start_loop
      end

      def write_pid
        SidekiqCluster.write_pid(@pid) if @pid
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second)
      end

      def continue_waiting?(deadline)
        SidekiqCluster.any_alive?(@processes) && monotonic_time < deadline
      end

      def hard_stop_stuck_pids
        SidekiqCluster.signal_processes(SidekiqCluster.pids_alive(@processes), :KILL)
      end

      def wait_for_termination
        deadline = monotonic_time + TERMINATE_TIMEOUT_SECONDS
        sleep(CHECK_TERMINATE_INTERVAL_SECONDS) while continue_waiting?(deadline)

        hard_stop_stuck_pids
      end

      def trap_signals
        SidekiqCluster.trap_terminate do |signal|
          @alive = false
          SidekiqCluster.signal_processes(@processes, signal)
          wait_for_termination
        end

        SidekiqCluster.trap_forward do |signal|
          SidekiqCluster.signal_processes(@processes, signal)
        end
      end

      def start_loop
        while @alive
          sleep(@interval)

          unless SidekiqCluster.all_alive?(@processes)
            # If a child process died we'll just terminate the whole cluster. It's up to
            # runit and such to then restart the cluster.
            @logger.info('A worker terminated, shutting down the cluster')

            SidekiqCluster.signal_processes(@processes, :TERM)
            break
          end
        end
      end

      def option_parser
        OptionParser.new do |opt|
          opt.banner = "#{File.basename(__FILE__)} [QUEUE,QUEUE] [QUEUE] ... [OPTIONS]"

          opt.separator "\nOptions:\n"

          opt.on('-h', '--help', 'Shows this help message') do
            abort opt.to_s
          end

          opt.on('-m', '--max-concurrency INT', 'Maximum threads to use with Sidekiq (default: 50, 0 to disable)') do |int|
            @max_concurrency = int.to_i
          end

          opt.on('--min-concurrency INT', 'Minimum threads to use with Sidekiq (default: 0)') do |int|
            @min_concurrency = int.to_i
          end

          opt.on('-e', '--environment ENV', 'The application environment') do |env|
            @environment = env
          end

          opt.on('-P', '--pidfile PATH', 'Path to the PID file') do |pid|
            @pid = pid
          end

          opt.on('-r', '--require PATH', 'Location of the Rails application') do |path|
            @rails_path = path
          end

          opt.on('--experimental-queue-selector', 'EXPERIMENTAL: Run workers based on the provided selector') do |experimental_queue_selector|
            @experimental_queue_selector = experimental_queue_selector
          end

          opt.on('-n', '--negate', 'Run workers for all queues in sidekiq_queues.yml except the given ones') do
            @negate_queues = true
          end

          opt.on('-i', '--interval INT', 'The number of seconds to wait between worker checks') do |int|
            @interval = int.to_i
          end

          opt.on('-d', '--dryrun', 'Print commands that would be run without this flag, and quit') do |int|
            @dryrun = true
          end
        end
      end
    end
  end
end
