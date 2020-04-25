# frozen_string_literal: true

require 'spec_helper'

describe Deployments::LinkMergeRequestsService do
  let(:project) { create(:project, :repository) }

  # *   ddd0f15 Merge branch 'po-fix-test-env-path' into 'master'
  # |\
  # | * 2d1db52 Correct test_env.rb path for adding branch
  # |/
  # *   1e292f8 Merge branch 'cherry-pick-ce369011' into 'master'
  # |\
  # | * c1c67ab Add file with a _flattable_ path
  # |/
  # *   7975be0 Merge branch 'rd-add-file-larger-than-1-mb' into 'master'
  let_it_be(:first_deployment_sha) { '7975be0116940bf2ad4321f79d02a55c5f7779aa' }
  let_it_be(:mr1_merge_commit_sha) { '1e292f8fedd741b75372e19097c76d327140c312' }
  let_it_be(:mr2_merge_commit_sha) { 'ddd0f15ae83993f5cb66a927a28673882e99100b' }

  describe '#execute' do
    context 'when the deployment is for a review environment' do
      it 'does nothing' do
        environment =
          create(:environment, environment_type: 'review', name: 'review/foo')

        deploy = create(:deployment, :success, environment: environment)

        expect(deploy).not_to receive(:link_merge_requests)

        described_class.new(deploy).execute
      end
    end

    context 'when there is a previous deployment' do
      it 'links all merge requests merged since the previous deployment' do
        deploy1 = create(
          :deployment,
          :success,
          project: project,
          sha: first_deployment_sha
        )

        deploy2 = create(
          :deployment,
          :success,
          project: deploy1.project,
          environment: deploy1.environment,
          sha: mr2_merge_commit_sha
        )

        service = described_class.new(deploy2)

        expect(service)
          .to receive(:link_merge_requests_for_range)
          .with(first_deployment_sha, mr2_merge_commit_sha)

        service.execute
      end
    end

    context 'when there are no previous deployments' do
      it 'links all merged merge requests' do
        deploy = create(:deployment, :success, project: project)
        service = described_class.new(deploy)

        expect(service).to receive(:link_all_merged_merge_requests)

        service.execute
      end
    end
  end

  describe '#link_merge_requests_for_range' do
    it 'links merge requests' do
      environment = create(:environment, project: project)
      deploy =
        create(:deployment, :success, project: project, environment: environment)

      mr1 = create(
        :merge_request,
        :merged,
        merge_commit_sha: mr1_merge_commit_sha,
        source_project: project,
        target_project: project
      )

      mr2 = create(
        :merge_request,
        :merged,
        merge_commit_sha: mr2_merge_commit_sha,
        source_project: project,
        target_project: project
      )

      described_class.new(deploy).link_merge_requests_for_range(
        first_deployment_sha,
        mr2_merge_commit_sha
      )

      expect(deploy.merge_requests).to include(mr1, mr2)
    end

    it 'links picked merge requests' do
      environment = create(:environment, project: project)
      deploy =
        create(:deployment, :success, project: project, environment: environment)

      picked_mr = create(
        :merge_request,
        :merged,
        merge_commit_sha: '123abc',
        source_project: project,
        target_project: project
      )

      mr1 = create(
        :merge_request,
        :merged,
        merge_commit_sha: mr1_merge_commit_sha,
        source_project: project,
        target_project: project
      )

      # mr1 includes c1c67abba which is a cherry-pick of the fake picked_mr merge request
      create(:track_mr_picking_note, noteable: picked_mr, project: project, commit_id: 'c1c67abbaf91f624347bb3ae96eabe3a1b742478')

      described_class.new(deploy).link_merge_requests_for_range(
        first_deployment_sha,
        mr1_merge_commit_sha
      )

      expect(deploy.merge_requests).to include(mr1, picked_mr)
    end

    context 'when :track_mr_picking feature flag is disabled' do
      before do
        stub_feature_flags(track_mr_picking: false)
      end

      it 'does not link picked merge requests' do
        environment = create(:environment, project: project)
        deploy =
          create(:deployment, :success, project: project, environment: environment)

        picked_mr = create(
          :merge_request,
          :merged,
          merge_commit_sha: '123abc',
          source_project: project,
          target_project: project
        )

        mr1 = create(
          :merge_request,
          :merged,
          merge_commit_sha: mr1_merge_commit_sha,
          source_project: project,
          target_project: project
        )

        # mr1 includes c1c67abba which is a cherry-pick of the fake picked_mr merge request
        create(:track_mr_picking_note, noteable: picked_mr, project: project, commit_id: 'c1c67abbaf91f624347bb3ae96eabe3a1b742478')

        mr2 = create(
          :merge_request,
          :merged,
          merge_commit_sha: mr2_merge_commit_sha,
          source_project: project,
          target_project: project
        )

        described_class.new(deploy).link_merge_requests_for_range(
          first_deployment_sha,
          mr2_merge_commit_sha
        )

        expect(deploy.merge_requests).to include(mr1, mr2)
        expect(deploy.merge_requests).not_to include(picked_mr)
      end
    end
  end

  describe '#link_all_merged_merge_requests' do
    it 'links all merged merge requests targeting the deployed branch' do
      environment = create(:environment, project: project)
      deploy =
        create(:deployment, :success, project: project, environment: environment)

      mr1 = create(
        :merge_request,
        :merged,
        source_project: project,
        target_project: project,
        source_branch: 'source1',
        target_branch: deploy.ref
      )

      mr2 = create(
        :merge_request,
        :merged,
        source_project: project,
        target_project: project,
        source_branch: 'source2',
        target_branch: deploy.ref
      )

      mr3 = create(
        :merge_request,
        :merged,
        source_project: project,
        target_project: project,
        target_branch: 'foo'
      )

      described_class.new(deploy).link_all_merged_merge_requests

      expect(deploy.merge_requests).to include(mr1, mr2)
      expect(deploy.merge_requests).not_to include(mr3)
    end
  end
end
