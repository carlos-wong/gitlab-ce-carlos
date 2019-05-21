require 'spec_helper'

describe Gitlab::HookData::MergeRequestBuilder do
  set(:merge_request) { create(:merge_request) }
  let(:builder) { described_class.new(merge_request) }

  describe '#build' do
    let(:data) { builder.build }

    it 'includes safe attribute' do
      %w[
        assignee_id
        assignee_ids
        author_id
        created_at
        description
        head_pipeline_id
        id
        iid
        last_edited_at
        last_edited_by_id
        merge_commit_sha
        merge_error
        merge_params
        merge_status
        merge_user_id
        merge_when_pipeline_succeeds
        milestone_id
        source_branch
        source_project_id
        state
        target_branch
        target_project_id
        time_estimate
        title
        updated_at
        updated_by_id
      ].each do |key|
        expect(data).to include(key)
      end
    end

    %i[source target].each do |key|
      describe "#{key} key" do
        include_examples 'project hook data', project_key: key do
          let(:project) { merge_request.public_send("#{key}_project") }
        end
      end
    end

    it 'includes additional attrs' do
      expect(data).to include(:source)
      expect(data).to include(:target)
      expect(data).to include(:last_commit)
      expect(data).to include(:work_in_progress)
      expect(data).to include(:total_time_spent)
      expect(data).to include(:human_time_estimate)
      expect(data).to include(:human_total_time_spent)
    end

    context 'when the MR has an image in the description' do
      let(:mr_with_description) { create(:merge_request, description: 'test![MR_Image](/uploads/abc/MR_Image.png)') }
      let(:builder) { described_class.new(mr_with_description) }

      it 'sets the image to use an absolute URL' do
        expected_path = "#{mr_with_description.project.path_with_namespace}/uploads/abc/MR_Image.png"

        expect(data[:description])
          .to eq("test![MR_Image](#{Settings.gitlab.url}/#{expected_path})")
      end
    end
  end
end
