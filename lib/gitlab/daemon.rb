# frozen_string_literal: true

module Gitlab
  class Daemon
    def self.initialize_instance(*args)
      raise "#{name} singleton instance already initialized" if @instance

      @instance = new(*args)
      Kernel.at_exit(&@instance.method(:stop))
      @instance
    end

    def self.instance(*args)
      @instance ||= initialize_instance(*args)
    end

    attr_reader :thread

    def thread?
      !thread.nil?
    end

    def initialize
      @mutex = Mutex.new
    end

    def enabled?
      true
    end

    def start
      return unless enabled?

      @mutex.synchronize do
        break thread if thread?

        @thread = Thread.new { start_working }
      end
    end

    def stop
      @mutex.synchronize do
        break unless thread?

        stop_working

        if thread
          thread.wakeup if thread.alive?
          begin
            thread.join unless Thread.current == thread
          rescue Exception # rubocop:disable Lint/RescueException
          end
          @thread = nil
        end
      end
    end

    private

    def start_working
      raise NotImplementedError
    end

    def stop_working
      # no-ops
    end
  end
end
