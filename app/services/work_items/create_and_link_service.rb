# frozen_string_literal: true

module WorkItems
  # Create and link operations are not run inside a transaction in this class
  # because CreateFromTaskService also creates a transaction.
  # This class should always be run inside a transaction as we could end up with
  # new work items that were never associated with other work items as expected.
  class CreateAndLinkService
    def initialize(project:, current_user: nil, params: {}, spam_params:, link_params: {})
      @create_service = CreateService.new(
        project: project,
        current_user: current_user,
        params: params,
        spam_params: spam_params
      )
      @project = project
      @current_user = current_user
      @link_params = link_params
    end

    def execute
      create_result = @create_service.execute
      return create_result if create_result.error?

      work_item = create_result[:work_item]
      return ::ServiceResponse.success(payload: payload(work_item)) if @link_params.blank?

      result = WorkItems::ParentLinks::CreateService.new(
        @link_params[:parent_work_item],
        @current_user,
        { target_issuable: work_item }
      ).execute

      if result[:status] == :success
        ::ServiceResponse.success(payload: payload(work_item))
      else
        ::ServiceResponse.error(message: result[:message], http_status: 404)
      end
    end

    private

    def payload(work_item)
      { work_item: work_item }
    end
  end
end
