# frozen_string_literal: true

require 'spec_helper'

describe Suggestions::ApplyService do
  include ProjectForksHelper

  let(:project) { create(:project, :repository) }
  let(:user) { create(:user, :commit_email) }

  let(:position) do
    Gitlab::Diff::Position.new(old_path: "files/ruby/popen.rb",
                               new_path: "files/ruby/popen.rb",
                               old_line: nil,
                               new_line: 9,
                               diff_refs: merge_request.diff_refs)
  end

  let(:suggestion) do
    create(:suggestion, note: diff_note,
                        from_content: "      raise RuntimeError, \"System commands must be given as an array of strings\"\n",
                        to_content: "      raise RuntimeError, 'Explosion'\n      # explosion?\n")
  end

  subject { described_class.new(user) }

  context 'patch is appliable' do
    let(:expected_content) do
      <<-CONTENT.strip_heredoc
          require 'fileutils'
          require 'open3'

          module Popen
            extend self

            def popen(cmd, path=nil)
              unless cmd.is_a?(Array)
                raise RuntimeError, 'Explosion'
                # explosion?
              end

              path ||= Dir.pwd

              vars = {
                "PWD" => path
              }

              options = {
                chdir: path
              }

              unless File.directory?(path)
                FileUtils.mkdir_p(path)
              end

              @cmd_output = ""
              @cmd_status = 0

              Open3.popen3(vars, *cmd, options) do |stdin, stdout, stderr, wait_thr|
                @cmd_output << stdout.read
                @cmd_output << stderr.read
                @cmd_status = wait_thr.value.exitstatus
              end

              return @cmd_output, @cmd_status
            end
          end
      CONTENT
    end

    context 'non-fork project' do
      let(:merge_request) do
        create(:merge_request, source_project: project,
                               target_project: project)
      end

      let!(:diff_note) do
        create(:diff_note_on_merge_request, noteable: merge_request,
                                            position: position,
                                            project: project)
      end

      before do
        project.add_maintainer(user)
      end

      it 'updates the file with the new contents' do
        subject.execute(suggestion)

        blob = project.repository.blob_at_branch(merge_request.source_branch,
                                                 position.new_path)

        expect(blob.data).to eq(expected_content)
      end

      it 'returns success status' do
        result = subject.execute(suggestion)

        expect(result[:status]).to eq(:success)
      end

      it 'updates suggestion applied and commit_id columns' do
        expect { subject.execute(suggestion) }
          .to change(suggestion, :applied)
          .from(false).to(true)
          .and change(suggestion, :commit_id)
          .from(nil)
      end

      it 'created commit has users email and name' do
        subject.execute(suggestion)

        commit = project.repository.commit

        expect(user.commit_email).not_to eq(user.email)
        expect(commit.author_email).to eq(user.commit_email)
        expect(commit.committer_email).to eq(user.commit_email)
        expect(commit.author_name).to eq(user.name)
      end

      context 'when it fails to apply because the file was changed' do
        it 'returns error message' do
          service = instance_double(Files::UpdateService)

          expect(Files::UpdateService).to receive(:new)
            .and_return(service)

          allow(service).to receive(:execute)
            .and_raise(Files::UpdateService::FileChangedError)

          result = subject.execute(suggestion)

          expect(result).to eq(message: 'The file has been changed', status: :error)
        end
      end

      context 'when diff ref from position is different from repo diff refs' do
        it 'returns error message' do
          outdated_refs = Gitlab::Diff::DiffRefs.new(base_sha: 'foo', start_sha: 'bar', head_sha: 'outdated')

          allow(suggestion).to receive(:appliable?) { true }
          allow(suggestion.position).to receive(:diff_refs) { outdated_refs }

          result = subject.execute(suggestion)

          expect(result).to eq(message: 'The file has been changed', status: :error)
        end
      end

      context 'multiple suggestions applied' do
        let(:expected_content) do
          <<-CONTENT.strip_heredoc
              require 'fileutils'
              require 'open3'

              module Popen
                extend self


                def popen(cmd, path=nil)
                  unless cmd.is_a?(Array)
                    # v1 change
                  end

                  path ||= Dir.pwd
                  # v1 change
                  vars = {
                    "PWD" => path
                  }

                  options = {
                    chdir: path
                  }
                  # v2 change
                  unless File.directory?(path)
                    FileUtils.mkdir_p(path)
                  end

                  @cmd_output = ""
                  # v2 change

                  Open3.popen3(vars, *cmd, options) do |stdin, stdout, stderr, wait_thr|
                    @cmd_output << stdout.read
                    @cmd_output << stderr.read
                    @cmd_status = wait_thr.value.exitstatus
                  end

                  return @cmd_output, @cmd_status
                end
              end
          CONTENT
        end

        let(:merge_request) do
          create(:merge_request, source_project: project,
                                 target_project: project)
        end

        def create_suggestion(diff, old_line: nil, new_line: nil, from_content:, to_content:, path:)
          position = Gitlab::Diff::Position.new(old_path: path,
                                                new_path: path,
                                                old_line: old_line,
                                                new_line: new_line,
                                                diff_refs: diff.diff_refs)

          suggestion_note = create(:diff_note_on_merge_request, noteable: merge_request,
                                                                original_position: position,
                                                                position: position,
                                                                project: project)
          create(:suggestion, note: suggestion_note,
                              from_content: from_content,
                              to_content: to_content)
        end

        def apply_suggestion(suggestion)
          suggestion.note.reload
          merge_request.reload
          merge_request.clear_memoized_shas

          result = subject.execute(suggestion)
          refresh = MergeRequests::RefreshService.new(project, user)
          refresh.execute(merge_request.diff_head_sha,
                          suggestion.commit_id,
                          merge_request.source_branch_ref)

          result
        end

        def fetch_raw_diff(suggestion)
          project.reload.commit(suggestion.commit_id).diffs.diff_files.first.diff.diff
        end

        it 'applies multiple suggestions in subsequent versions correctly' do
          diff = merge_request.merge_request_diff
          path = 'files/ruby/popen.rb'

          suggestion_1_changes = { old_line: nil,
                                   new_line: 13,
                                   from_content: "\n",
                                   to_content: "# v1 change\n",
                                   path: path }

          suggestion_2_changes = { old_line: 24,
                                   new_line: 31,
                                   from_content: "       @cmd_output << stderr.read\n",
                                   to_content: "# v2 change\n",
                                   path: path }

          suggestion_1 = create_suggestion(diff, suggestion_1_changes)
          suggestion_2 = create_suggestion(diff, suggestion_2_changes)

          apply_suggestion(suggestion_1)

          suggestion_1_diff = fetch_raw_diff(suggestion_1)

          # rubocop: disable Layout/TrailingWhitespace
          expected_suggestion_1_diff = <<-CONTENT.strip_heredoc
            @@ -10,7 +10,7 @@ module Popen
                 end
             
                 path ||= Dir.pwd
            -
            +# v1 change
                 vars = {
                   "PWD" => path
                 }
          CONTENT
          # rubocop: enable Layout/TrailingWhitespace

          apply_suggestion(suggestion_2)

          suggestion_2_diff = fetch_raw_diff(suggestion_2)

          # rubocop: disable Layout/TrailingWhitespace
          expected_suggestion_2_diff = <<-CONTENT.strip_heredoc
            @@ -28,7 +28,7 @@ module Popen
             
                 Open3.popen3(vars, *cmd, options) do |stdin, stdout, stderr, wait_thr|
                   @cmd_output << stdout.read
            -      @cmd_output << stderr.read
            +# v2 change
                   @cmd_status = wait_thr.value.exitstatus
                 end
          CONTENT
          # rubocop: enable Layout/TrailingWhitespace

          expect(suggestion_1_diff.strip).to eq(expected_suggestion_1_diff.strip)
          expect(suggestion_2_diff.strip).to eq(expected_suggestion_2_diff.strip)
        end
      end
    end

    context 'fork-project' do
      let(:project) { create(:project, :public, :repository) }

      let(:forked_project) do
        fork_project_with_submodules(project, user, repository: project.repository)
      end

      let(:merge_request) do
        create(:merge_request,
               source_branch: 'conflict-resolvable-fork', source_project: forked_project,
               target_branch: 'conflict-start', target_project: project)
      end

      let!(:diff_note) do
        create(:diff_note_on_merge_request, noteable: merge_request, position: position, project: project)
      end

      before do
        project.add_maintainer(user)
      end

      it 'updates file in the source project' do
        expect(Files::UpdateService).to receive(:new)
          .with(merge_request.source_project, user, anything)
          .and_call_original

        subject.execute(suggestion)
      end
    end
  end

  context 'no permission' do
    let(:merge_request) do
      create(:merge_request, source_project: project,
                             target_project: project)
    end

    let(:diff_note) do
      create(:diff_note_on_merge_request, noteable: merge_request,
                                          position: position,
                                          project: project)
    end

    context 'user cannot write in project repo' do
      before do
        project.add_reporter(user)
      end

      it 'returns error' do
        result = subject.execute(suggestion)

        expect(result).to eq(message: "You are not allowed to push into this branch",
                             status: :error)
      end
    end
  end

  context 'patch is not appliable' do
    let(:merge_request) do
      create(:merge_request, source_project: project,
                             target_project: project)
    end

    let(:diff_note) do
      create(:diff_note_on_merge_request, noteable: merge_request,
                                          position: position,
                                          project: project)
    end

    before do
      project.add_maintainer(user)
    end

    context 'suggestion was already applied' do
      it 'returns success status' do
        result = subject.execute(suggestion)

        expect(result[:status]).to eq(:success)
      end
    end

    context 'note is outdated' do
      before do
        allow(diff_note).to receive(:active?) { false }
      end

      it 'returns error message' do
        result = subject.execute(suggestion)

        expect(result).to eq(message: 'Suggestion is not appliable',
                             status: :error)
      end
    end

    context 'suggestion was already applied' do
      before do
        suggestion.update!(applied: true, commit_id: 'sha')
      end

      it 'returns error message' do
        result = subject.execute(suggestion)

        expect(result).to eq(message: 'Suggestion is not appliable',
                             status: :error)
      end
    end
  end
end
