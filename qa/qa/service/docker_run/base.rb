# frozen_string_literal: true

module QA
  module Service
    module DockerRun
      class Base
        include Service::Shellout

        def initialize
          @network = Runtime::Scenario.attributes[:network] || 'test'
        end

        def network
          shell "docker network inspect #{@network}"
        rescue CommandError
          'bridge'
        else
          @network
        end

        def pull
          shell "docker pull #{@image}"
        end

        def host_name
          "#{@name}.#{network}"
        end

        def register!
          raise NotImplementedError
        end

        def remove!
          shell "docker rm -f #{@name}" if running?
        end

        def running?
          `docker ps -f name=#{@name}`.include?(@name)
        end
      end
    end
  end
end
