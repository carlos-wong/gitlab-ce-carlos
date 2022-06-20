# frozen_string_literal: true

module Users
  class InProductMarketingEmail < ApplicationRecord
    include BulkInsertSafe

    belongs_to :user

    validates :user, presence: true
    validates :track, presence: true
    validates :series, presence: true
    validates :user_id, uniqueness: {
      scope: [:track, :series],
      message: 'has already been sent'
    }

    enum track: {
      create: 0,
      verify: 1,
      trial: 2,
      team: 3,
      experience: 4,
      team_short: 5,
      trial_short: 6,
      admin_verify: 7,
      invite_team: 8
    }, _suffix: true

    # Tracks we don't send emails for (e.g. unsuccessful experiment). These
    # are kept since we already have DB records that use the enum value.
    INACTIVE_TRACK_NAMES = %w(invite_team).freeze
    ACTIVE_TRACKS = tracks.except(*INACTIVE_TRACK_NAMES)

    scope :without_track_and_series, -> (track, series) do
      users = User.arel_table
      product_emails = arel_table

      join_condition = users[:id].eq(product_emails[:user_id])
        .and(product_emails[:track]).eq(ACTIVE_TRACKS[track])
        .and(product_emails[:series]).eq(series)

      arel_join = users.join(product_emails, Arel::Nodes::OuterJoin).on(join_condition)

      joins(arel_join.join_sources)
        .where(in_product_marketing_emails: { id: nil })
        .select(Arel.sql("DISTINCT ON(#{users.table_name}.id) #{users.table_name}.*"))
    end

    scope :for_user_with_track_and_series, -> (user, track, series) do
      where(user: user, track: track, series: series)
    end

    def self.save_cta_click(user, track, series)
      email = for_user_with_track_and_series(user, track, series).take

      email.update(cta_clicked_at: Time.zone.now) if email && email.cta_clicked_at.blank?
    end
  end
end
