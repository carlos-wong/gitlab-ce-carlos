# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Seed
        class Stage < Seed::Base
          include Gitlab::Utils::StrongMemoize

          delegate :size, to: :seeds
          delegate :dig, to: :seeds

          def initialize(pipeline, attributes)
            @pipeline = pipeline
            @attributes = attributes

            @builds = attributes.fetch(:builds).map do |attributes|
              Seed::Build.new(@pipeline, attributes)
            end
          end

          def attributes
            { name: @attributes.fetch(:name),
              position: @attributes.fetch(:index),
              pipeline: @pipeline,
              project: @pipeline.project }
          end

          def seeds
            strong_memoize(:seeds) do
              @builds.select(&:included?)
            end
          end

          def included?
            seeds.any?
          end

          def to_resource
            strong_memoize(:stage) do
              ::Ci::Stage.new(attributes).tap do |stage|
                seeds.each do |seed|
                  if seed.bridge?
                    stage.bridges << seed.to_resource
                  else
                    stage.builds << seed.to_resource
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
