# frozen_string_literal: true

class RemoveExpiredMembersWorker
  include ApplicationWorker
  include CronjobQueue

  def perform
    Member.expired.find_each do |member|
      Members::DestroyService.new.execute(member, skip_authorization: true)
    rescue => ex
      logger.error("Expired Member ID=#{member.id} cannot be removed - #{ex}")
    end
  end
end
