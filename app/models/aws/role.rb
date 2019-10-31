# frozen_string_literal: true

module Aws
  class Role < ApplicationRecord
    self.table_name = 'aws_roles'

    belongs_to :user, inverse_of: :aws_role

    validates :role_external_id, uniqueness: true, length: { in: 1..64 }
    validates :role_arn,
      length: 1..2048,
      format: {
        with: Gitlab::Regex.aws_arn_regex,
        message: Gitlab::Regex.aws_arn_regex_message
      }
  end
end
