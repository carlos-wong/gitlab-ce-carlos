# frozen_string_literal: true

module Gitlab
  module GitalyClient
    class RemoteService
      include Gitlab::EncodingHelper

      MAX_MSG_SIZE = 128.kilobytes.freeze

      def self.exists?(remote_url)
        request = Gitaly::FindRemoteRepositoryRequest.new(remote: remote_url)

        response = GitalyClient.call(GitalyClient.random_storage,
                                     :remote_service,
                                     :find_remote_repository, request,
                                     timeout: GitalyClient.medium_timeout)

        response.exists
      end

      def initialize(repository)
        @repository = repository
        @gitaly_repo = repository.gitaly_repository
        @storage = repository.storage
      end

      def add_remote(name, url, mirror_refmaps)
        request = Gitaly::AddRemoteRequest.new(
          repository: @gitaly_repo,
          name: name,
          url: url,
          mirror_refmaps: Array.wrap(mirror_refmaps).map(&:to_s)
        )

        GitalyClient.call(@storage, :remote_service, :add_remote, request, timeout: GitalyClient.fast_timeout)
      end

      def remove_remote(name)
        request = Gitaly::RemoveRemoteRequest.new(repository: @gitaly_repo, name: name)

        response = GitalyClient.call(@storage, :remote_service, :remove_remote, request)

        response.result
      end

      def fetch_internal_remote(repository)
        request = Gitaly::FetchInternalRemoteRequest.new(
          repository: @gitaly_repo,
          remote_repository: repository.gitaly_repository
        )

        response = GitalyClient.call(@storage, :remote_service,
                                     :fetch_internal_remote, request,
                                     remote_storage: repository.storage)

        response.result
      end

      def find_remote_root_ref(remote_name)
        request = Gitaly::FindRemoteRootRefRequest.new(
          repository: @gitaly_repo,
          remote: remote_name
        )

        response = GitalyClient.call(@storage, :remote_service,
                                     :find_remote_root_ref, request)

        encode_utf8(response.ref)
      end

      def update_remote_mirror(ref_name, only_branches_matching, ssh_key: nil, known_hosts: nil)
        req_enum = Enumerator.new do |y|
          first_request = Gitaly::UpdateRemoteMirrorRequest.new(
            repository: @gitaly_repo,
            ref_name: ref_name
          )

          first_request.ssh_key = ssh_key if ssh_key.present?
          first_request.known_hosts = known_hosts if known_hosts.present?

          y.yield(first_request)

          current_size = 0

          slices = only_branches_matching.slice_before do |branch_name|
            current_size += branch_name.bytesize

            next false if current_size < MAX_MSG_SIZE

            current_size = 0
          end

          slices.each do |slice|
            y.yield Gitaly::UpdateRemoteMirrorRequest.new(only_branches_matching: slice)
          end
        end

        GitalyClient.call(@storage, :remote_service, :update_remote_mirror, req_enum)
      end
    end
  end
end
