# frozen_string_literal: true

# PostReceiveService class
#
# Used for scheduling related jobs after a push action has been performed
class PostReceiveService
  attr_reader :user, :project, :params

  def initialize(user, project, params)
    @user = user
    @project = project
    @params = params
  end

  def execute
    response = Gitlab::InternalPostReceive::Response.new

    push_options = Gitlab::PushOptions.new(params[:push_options])

    response.reference_counter_decreased = Gitlab::ReferenceCounter.new(params[:gl_repository]).decrease

    PostReceive.perform_async(params[:gl_repository], params[:identifier],
                              params[:changes], push_options.as_json)

    mr_options = push_options.get(:merge_request)
    if mr_options.present?
      message = process_mr_push_options(mr_options, project, user, params[:changes])
      response.add_alert_message(message)
    end

    broadcast_message = BroadcastMessage.current&.last&.message
    response.add_alert_message(broadcast_message)

    response.add_merge_request_urls(merge_request_urls)

    # Neither User nor Project are guaranteed to be returned; an orphaned write deploy
    # key could be used
    if user && project
      redirect_message = Gitlab::Checks::ProjectMoved.fetch_message(user.id, project.id)
      project_created_message = Gitlab::Checks::ProjectCreated.fetch_message(user.id, project.id)

      response.add_basic_message(redirect_message)
      response.add_basic_message(project_created_message)
    end

    response
  end

  def process_mr_push_options(push_options, project, user, changes)
    Gitlab::QueryLimiting.whitelist('https://gitlab.com/gitlab-org/gitlab-foss/issues/61359')

    service = ::MergeRequests::PushOptionsHandlerService.new(
      project, user, changes, push_options
    ).execute

    if service.errors.present?
      push_options_warning(service.errors.join("\n\n"))
    end
  end

  def push_options_warning(warning)
    options = Array.wrap(params[:push_options]).map { |p| "'#{p}'" }.join(' ')
    "WARNINGS:\nError encountered with push options #{options}: #{warning}"
  end

  def merge_request_urls
    ::MergeRequests::GetUrlsService.new(project).execute(params[:changes])
  end
end
