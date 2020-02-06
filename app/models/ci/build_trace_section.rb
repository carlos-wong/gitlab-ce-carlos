# frozen_string_literal: true

module Ci
  class BuildTraceSection < ApplicationRecord
    extend Gitlab::Ci::Model

    belongs_to :build, class_name: 'Ci::Build'
    belongs_to :project
    belongs_to :section_name, class_name: 'Ci::BuildTraceSectionName'

    validates :section_name, :build, :project, presence: true, allow_blank: false
  end
end
