# frozen_string_literal: true

shared_examples 'latest successful build for sha or ref' do
  context 'with many builds' do
    let(:other_pipeline) { create_pipeline(project) }
    let(:other_build) { create_build(other_pipeline, 'test') }
    let(:build_name) { other_build.name }

    before do
      pipeline1 = create_pipeline(project)
      pipeline2 = create_pipeline(project)
      create_build(pipeline1, 'test')
      create_build(pipeline1, 'test2')
      create_build(pipeline2, 'test2')
    end

    it 'gives the latest builds from latest pipeline' do
      expect(subject).to eq(other_build)
    end
  end

  context 'with succeeded pipeline' do
    let!(:build) { create_build }
    let(:build_name) { build.name }

    context 'standalone pipeline' do
      it 'returns builds for ref for default_branch' do
        expect(subject).to eq(build)
      end

      context 'with nonexistent build' do
        let(:build_name) { 'TAIL' }

        it 'returns empty relation if the build cannot be found' do
          expect(subject).to be_nil
        end
      end
    end

    context 'with some pending pipeline' do
      before do
        create_build(create_pipeline(project, 'pending'))
      end

      it 'gives the latest build from latest pipeline' do
        expect(subject).to eq(build)
      end
    end
  end

  context 'with pending pipeline' do
    let!(:pending_build) { create_build(pipeline) }
    let(:build_name) { pending_build.name }

    before do
      pipeline.update(status: 'pending')
    end

    it 'returns empty relation' do
      expect(subject).to be_nil
    end
  end
end
