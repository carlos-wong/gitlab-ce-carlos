# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module Entry
        ##
        # Entry that represents a concrete CI/CD job.
        #
        class Job < ::Gitlab::Config::Entry::Node
          include ::Gitlab::Ci::Config::Entry::Processable

          ALLOWED_WHEN = %w[on_success on_failure always manual delayed].freeze
          ALLOWED_KEYS = %i[tags script type image services
                            allow_failure type when start_in artifacts cache
                            dependencies before_script needs after_script
                            environment coverage retry parallel interruptible timeout
                            resource_group release].freeze

          REQUIRED_BY_NEEDS = %i[stage].freeze

          validations do
            validates :config, allowed_keys: ALLOWED_KEYS + PROCESSABLE_ALLOWED_KEYS
            validates :config, required_keys: REQUIRED_BY_NEEDS, if: :has_needs?
            validates :script, presence: true
            validates :config,
              disallowed_keys: {
                in: %i[release],
                message: 'release features are not enabled'
              },
              unless: -> { Feature.enabled?(:ci_release_generation, default_enabled: false) }

            with_options allow_nil: true do
              validates :allow_failure, boolean: true
              validates :parallel, numericality: { only_integer: true,
                                                   greater_than_or_equal_to: 2,
                                                   less_than_or_equal_to: 50 }
              validates :when, inclusion: {
                in: ALLOWED_WHEN,
                message: "should be one of: #{ALLOWED_WHEN.join(', ')}"
              }

              validates :dependencies, array_of_strings: true
              validates :resource_group, type: String
            end

            validates :start_in, duration: { limit: '1 week' }, if: :delayed?
            validates :start_in, absence: true, if: -> { has_rules? || !delayed? }

            validate on: :composed do
              next unless dependencies.present?
              next unless needs_value.present?

              missing_needs = dependencies - needs_value[:job].pluck(:name) # rubocop:disable CodeReuse/ActiveRecord (Array#pluck)

              if missing_needs.any?
                errors.add(:dependencies, "the #{missing_needs.join(", ")} should be part of needs")
              end
            end
          end

          entry :before_script, Entry::Script,
            description: 'Global before script overridden in this job.',
            inherit: true

          entry :script, Entry::Commands,
            description: 'Commands that will be executed in this job.',
            inherit: false

          entry :type, Entry::Stage,
            description: 'Deprecated: stage this job will be executed into.',
            inherit: false

          entry :after_script, Entry::Script,
            description: 'Commands that will be executed when finishing job.',
            inherit: true

          entry :cache, Entry::Cache,
            description: 'Cache definition for this job.',
            inherit: true

          entry :image, Entry::Image,
            description: 'Image that will be used to execute this job.',
            inherit: true

          entry :services, Entry::Services,
            description: 'Services that will be used to execute this job.',
            inherit: true

          entry :interruptible, ::Gitlab::Config::Entry::Boolean,
            description: 'Set jobs interruptible value.',
            inherit: true

          entry :timeout, Entry::Timeout,
            description: 'Timeout duration of this job.',
            inherit: true

          entry :retry, Entry::Retry,
            description: 'Retry configuration for this job.',
            inherit: true

          entry :tags, ::Gitlab::Config::Entry::ArrayOfStrings,
            description: 'Set the tags.',
            inherit: true

          entry :artifacts, Entry::Artifacts,
            description: 'Artifacts configuration for this job.',
            inherit: true

          entry :needs, Entry::Needs,
            description: 'Needs configuration for this job.',
            metadata: { allowed_needs: %i[job cross_dependency] },
            inherit: false

          entry :environment, Entry::Environment,
            description: 'Environment configuration for this job.',
            inherit: false

          entry :coverage, Entry::Coverage,
            description: 'Coverage configuration for this job.',
            inherit: false

          entry :release, Entry::Release,
            description: 'This job will produce a release.',
            inherit: false

          attributes :script, :tags, :allow_failure, :when, :dependencies,
                     :needs, :retry, :parallel, :start_in,
                     :interruptible, :timeout, :resource_group, :release

          def self.matching?(name, config)
            !name.to_s.start_with?('.') &&
              config.is_a?(Hash) && config.key?(:script)
          end

          def self.visible?
            true
          end

          def compose!(deps = nil)
            super do
              if type_defined? && !stage_defined?
                @entries[:stage] = @entries[:type]
              end

              @entries.delete(:type)
            end
          end

          def manual_action?
            self.when == 'manual'
          end

          def delayed?
            self.when == 'delayed'
          end

          def ignored?
            allow_failure.nil? ? manual_action? : allow_failure
          end

          def value
            super.merge(
              before_script: before_script_value,
              script: script_value,
              image: image_value,
              services: services_value,
              cache: cache_value,
              tags: tags_value,
              when: self.when,
              start_in: self.start_in,
              dependencies: dependencies,
              environment: environment_defined? ? environment_value : nil,
              environment_name: environment_defined? ? environment_value[:name] : nil,
              coverage: coverage_defined? ? coverage_value : nil,
              retry: retry_defined? ? retry_value : nil,
              parallel: has_parallel? ? parallel.to_i : nil,
              interruptible: interruptible_defined? ? interruptible_value : nil,
              timeout: has_timeout? ? ChronicDuration.parse(timeout.to_s) : nil,
              artifacts: artifacts_value,
              release: release_value,
              after_script: after_script_value,
              ignore: ignored?,
              needs: needs_defined? ? needs_value : nil,
              resource_group: resource_group,
              scheduling_type: needs_defined? ? :dag : :stage
            ).compact
          end
        end
      end
    end
  end
end
