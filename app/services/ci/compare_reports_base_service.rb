# frozen_string_literal: true

module Ci
  # TODO: when using this class with exposed artifacts we see that there are
  # 2 responsibilities:
  # 1. reactive caching interface (same in all cases)
  # 2. data generator (report comparison in most of the case but not always)
  # issue: https://gitlab.com/gitlab-org/gitlab/issues/34224
  class CompareReportsBaseService < ::BaseService
    def execute(base_pipeline, head_pipeline)
      comparer = comparer_class.new(get_report(base_pipeline), get_report(head_pipeline))
      {
        status: :parsed,
        key: key(base_pipeline, head_pipeline),
        data: serializer_class
          .new(**serializer_params)
          .represent(comparer).as_json
      }
    rescue Gitlab::Ci::Parsers::ParserError => e
      {
        status: :error,
        key: key(base_pipeline, head_pipeline),
        status_reason: e.message
      }
    end

    def latest?(base_pipeline, head_pipeline, data)
      data&.fetch(:key, nil) == key(base_pipeline, head_pipeline)
    end

    private

    def key(base_pipeline, head_pipeline)
      [
        base_pipeline&.id, base_pipeline&.updated_at,
        head_pipeline&.id, head_pipeline&.updated_at
      ]
    end

    def comparer_class
      raise NotImplementedError
    end

    def serializer_class
      raise NotImplementedError
    end

    def serializer_params
      { project: project, current_user: current_user }
    end

    def get_report(pipeline)
      raise NotImplementedError
    end
  end
end
