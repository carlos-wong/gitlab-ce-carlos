# frozen_string_literal: true

require 'mime/types'

module API
  class Repositories < Grape::API
    include PaginationParams

    helpers ::API::Helpers::HeadersHelpers

    before { authorize! :download_code, user_project }

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      helpers do
        include ::Gitlab::RateLimitHelpers

        def handle_project_member_errors(errors)
          if errors[:project_access].any?
            error!(errors[:project_access], 422)
          end

          not_found!
        end

        def assign_blob_vars!
          authorize! :download_code, user_project

          @repo = user_project.repository

          begin
            @blob = Gitlab::Git::Blob.raw(@repo, params[:sha])
            @blob.load_all_data!(@repo)
          rescue
            not_found! 'Blob'
          end

          not_found! 'Blob' unless @blob
        end
      end

      desc 'Get a project repository tree' do
        success Entities::TreeObject
      end
      params do
        optional :ref, type: String, desc: 'The name of a repository branch or tag, if not given the default branch is used'
        optional :path, type: String, desc: 'The path of the tree'
        optional :recursive, type: Boolean, default: false, desc: 'Used to get a recursive tree'
        use :pagination
      end
      get ':id/repository/tree' do
        ref = params[:ref] || user_project.try(:default_branch) || 'master'
        path = params[:path] || nil

        commit = user_project.commit(ref)
        not_found!('Tree') unless commit

        tree = user_project.repository.tree(commit.id, path, recursive: params[:recursive])
        entries = ::Kaminari.paginate_array(tree.sorted_entries)
        present paginate(entries), with: Entities::TreeObject
      end

      desc 'Get raw blob contents from the repository'
      params do
        requires :sha, type: String, desc: 'The commit hash'
      end
      get ':id/repository/blobs/:sha/raw' do
        assign_blob_vars!

        no_cache_headers

        send_git_blob @repo, @blob
      end

      desc 'Get a blob from the repository'
      params do
        requires :sha, type: String, desc: 'The commit hash'
      end
      get ':id/repository/blobs/:sha' do
        assign_blob_vars!

        {
          size: @blob.size,
          encoding: "base64",
          content: Base64.strict_encode64(@blob.data),
          sha: @blob.id
        }
      end

      desc 'Get an archive of the repository'
      params do
        optional :sha, type: String, desc: 'The commit sha of the archive to be downloaded'
        optional :format, type: String, desc: 'The archive format'
      end
      get ':id/repository/archive', requirements: { format: Gitlab::PathRegex.archive_formats_regex } do
        if archive_rate_limit_reached?(current_user, user_project)
          render_api_error!({ error: ::Gitlab::RateLimitHelpers::ARCHIVE_RATE_LIMIT_REACHED_MESSAGE }, 429)
        end

        not_acceptable! if Gitlab::HotlinkingDetector.intercept_hotlinking?(request)

        send_git_archive user_project.repository, ref: params[:sha], format: params[:format], append_sha: true
      rescue
        not_found!('File')
      end

      desc 'Compare two branches, tags, or commits' do
        success Entities::Compare
      end
      params do
        requires :from, type: String, desc: 'The commit, branch name, or tag name to start comparison'
        requires :to, type: String, desc: 'The commit, branch name, or tag name to stop comparison'
        optional :straight, type: Boolean, desc: 'Comparison method, `true` for direct comparison between `from` and `to` (`from`..`to`), `false` to compare using merge base (`from`...`to`)', default: false
      end
      get ':id/repository/compare' do
        compare = CompareService.new(user_project, params[:to]).execute(user_project, params[:from], straight: params[:straight])

        if compare
          present compare, with: Entities::Compare
        else
          not_found!("Ref")
        end
      end

      desc 'Get repository contributors' do
        success Entities::Contributor
      end
      params do
        use :pagination
        optional :order_by, type: String, values: %w[email name commits], default: 'commits', desc: 'Return contributors ordered by `name` or `email` or `commits`'
        optional :sort, type: String, values: %w[asc desc], default: 'asc', desc: 'Sort by asc (ascending) or desc (descending)'
      end
      get ':id/repository/contributors' do
        contributors = ::Kaminari.paginate_array(user_project.repository.contributors(order_by: params[:order_by], sort: params[:sort]))
        present paginate(contributors), with: Entities::Contributor
      rescue
        not_found!
      end

      desc 'Get the common ancestor between commits' do
        success Entities::Commit
      end
      params do
        requires :refs, type: Array[String]
      end
      get ':id/repository/merge_base' do
        refs = params[:refs]

        if refs.size < 2
          render_api_error!('Provide at least 2 refs', 400)
        end

        merge_base = Gitlab::Git::MergeBase.new(user_project.repository, refs)

        if merge_base.unknown_refs.any?
          ref_noun = 'ref'.pluralize(merge_base.unknown_refs.size)
          message = "Could not find #{ref_noun}: #{merge_base.unknown_refs.join(', ')}"
          render_api_error!(message, 400)
        end

        if merge_base.commit
          present merge_base.commit, with: Entities::Commit
        else
          not_found!("Merge Base")
        end
      end
    end
  end
end
