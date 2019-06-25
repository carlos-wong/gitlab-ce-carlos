shared_examples_for 'common trace features' do
  describe '#html' do
    before do
      trace.set("12\n34")
    end

    it "returns formatted html" do
      expect(trace.html).to eq("<span class=\"\">12<br/><span class=\"\">34</span></span>")
    end

    it "returns last line of formatted html" do
      expect(trace.html(last_lines: 1)).to eq("<span class=\"\">34</span>")
    end
  end

  describe '#raw' do
    before do
      trace.set("12\n34")
    end

    it "returns raw output" do
      expect(trace.raw).to eq("12\n34")
    end

    it "returns last line of raw output" do
      expect(trace.raw(last_lines: 1)).to eq("34")
    end
  end

  describe '#extract_coverage' do
    let(:regex) { '\(\d+.\d+\%\) covered' }

    context 'matching coverage' do
      before do
        trace.set('Coverage 1033 / 1051 LOC (98.29%) covered')
      end

      it "returns valid coverage" do
        expect(trace.extract_coverage(regex)).to eq("98.29")
      end
    end

    context 'no coverage' do
      before do
        trace.set('No coverage')
      end

      it 'returs nil' do
        expect(trace.extract_coverage(regex)).to be_nil
      end
    end
  end

  describe '#extract_sections' do
    let(:log) { 'No sections' }
    let(:sections) { trace.extract_sections }

    before do
      trace.set(log)
    end

    context 'no sections' do
      it 'returs []' do
        expect(trace.extract_sections).to eq([])
      end
    end

    context 'multiple sections available' do
      let(:log) { File.read(expand_fixture_path('trace/trace_with_sections')) }
      let(:sections_data) do
        [
          { name: 'prepare_script', lines: 2, duration: 3.seconds },
          { name: 'get_sources', lines: 4, duration: 1.second },
          { name: 'restore_cache', lines: 0, duration: 0.seconds },
          { name: 'download_artifacts', lines: 0, duration: 0.seconds },
          { name: 'build_script', lines: 2, duration: 1.second },
          { name: 'after_script', lines: 0, duration: 0.seconds },
          { name: 'archive_cache', lines: 0, duration: 0.seconds },
          { name: 'upload_artifacts', lines: 0, duration: 0.seconds }
        ]
      end

      it "returns valid sections" do
        expect(sections).not_to be_empty
        expect(sections.size).to eq(sections_data.size),
                                 "expected #{sections_data.size} sections, got #{sections.size}"

        buff = StringIO.new(log)
        sections.each_with_index do |s, i|
          expected = sections_data[i]

          expect(s[:name]).to eq(expected[:name])
          expect(s[:date_end] - s[:date_start]).to eq(expected[:duration])

          buff.seek(s[:byte_start], IO::SEEK_SET)
          length = s[:byte_end] - s[:byte_start]
          lines = buff.read(length).count("\n")
          expect(lines).to eq(expected[:lines])
        end
      end
    end

    context 'logs contains "section_start"' do
      let(:log) { "section_start:1506417476:a_section\r\033[0Klooks like a section_start:invalid\nsection_end:1506417477:a_section\r\033[0K"}

      it "returns only one section" do
        expect(sections).not_to be_empty
        expect(sections.size).to eq(1)

        section = sections[0]
        expect(section[:name]).to eq('a_section')
        expect(section[:byte_start]).not_to eq(section[:byte_end]), "got an empty section"
      end
    end

    context 'missing section_end' do
      let(:log) { "section_start:1506417476:a_section\r\033[0KSome logs\nNo section_end\n"}

      it "returns no sections" do
        expect(sections).to be_empty
      end
    end

    context 'missing section_start' do
      let(:log) { "Some logs\nNo section_start\nsection_end:1506417476:a_section\r\033[0K"}

      it "returns no sections" do
        expect(sections).to be_empty
      end
    end

    context 'inverted section_start section_end' do
      let(:log) { "section_end:1506417476:a_section\r\033[0Klooks like a section_start:invalid\nsection_start:1506417477:a_section\r\033[0K"}

      it "returns no sections" do
        expect(sections).to be_empty
      end
    end
  end

  describe '#write' do
    subject { trace.send(:write, mode) { } }

    let(:mode) { 'wb' }

    context 'when arhicved trace does not exist yet' do
      it 'does not raise an error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when arhicved trace already exists' do
      before do
        create(:ci_job_artifact, :trace, job: build)
      end

      it 'raises an error' do
        expect { subject }.to raise_error(Gitlab::Ci::Trace::AlreadyArchivedError)
      end
    end
  end

  describe '#set' do
    before do
      trace.set("12")
    end

    it "returns trace" do
      expect(trace.raw).to eq("12")
    end

    context 'overwrite trace' do
      before do
        trace.set("34")
      end

      it "returns new trace" do
        expect(trace.raw).to eq("34")
      end
    end

    context 'runners token' do
      let(:token) { build.project.runners_token }

      before do
        trace.set(token)
      end

      it "hides token" do
        expect(trace.raw).not_to include(token)
      end
    end

    context 'hides build token' do
      let(:token) { build.token }

      before do
        trace.set(token)
      end

      it "hides token" do
        expect(trace.raw).not_to include(token)
      end
    end
  end

  describe '#append' do
    before do
      trace.set("1234")
    end

    it "returns correct trace" do
      expect(trace.append("56", 4)).to eq(6)
      expect(trace.raw).to eq("123456")
    end

    context 'tries to append trace at different offset' do
      it "fails with append" do
        expect(trace.append("56", 2)).to eq(4)
        expect(trace.raw).to eq("1234")
      end
    end

    context 'runners token' do
      let(:token) { 'my_secret_token' }

      before do
        build.project.update(runners_token: token)
        trace.append(token, 0)
      end

      it "hides token" do
        expect(trace.raw).not_to include(token)
      end
    end

    context 'build token' do
      let(:token) { 'my_secret_token' }

      before do
        build.update(token: token)
        trace.append(token, 0)
      end

      it "hides token" do
        expect(trace.raw).not_to include(token)
      end
    end
  end

  describe '#archive!' do
    subject { trace.archive! }

    context 'when build status is success' do
      let!(:build) { create(:ci_build, :success, :trace_live) }

      it 'does not have an archived trace yet' do
        expect(build.job_artifacts_trace).to be_nil
      end

      context 'when archives' do
        it 'has an archived trace' do
          subject

          build.reload
          expect(build.job_artifacts_trace).to be_exist
        end

        context 'when another process has already been archiving', :clean_gitlab_redis_shared_state do
          include ExclusiveLeaseHelpers

          before do
            stub_exclusive_lease_taken("trace:write:lock:#{trace.job.id}", timeout: 1.minute)
          end

          it 'blocks concurrent archiving' do
            expect { subject }.to raise_error(::Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
          end
        end
      end
    end
  end
end

shared_examples_for 'trace with disabled live trace feature' do
  it_behaves_like 'common trace features'

  describe '#read' do
    shared_examples 'read successfully with IO' do
      it 'yields with source' do
        trace.read do |stream|
          expect(stream).to be_a(Gitlab::Ci::Trace::Stream)
          expect(stream.stream).to be_a(IO)
        end
      end
    end

    shared_examples 'read successfully with StringIO' do
      it 'yields with source' do
        trace.read do |stream|
          expect(stream).to be_a(Gitlab::Ci::Trace::Stream)
          expect(stream.stream).to be_a(StringIO)
        end
      end
    end

    shared_examples 'failed to read' do
      it 'yields without source' do
        trace.read do |stream|
          expect(stream).to be_a(Gitlab::Ci::Trace::Stream)
          expect(stream.stream).to be_nil
        end
      end
    end

    context 'when trace artifact exists' do
      before do
        create(:ci_job_artifact, :trace, job: build)
      end

      it_behaves_like 'read successfully with IO'
    end

    context 'when current_path (with project_id) exists' do
      before do
        expect(trace).to receive(:default_path) { expand_fixture_path('trace/sample_trace') }
      end

      it_behaves_like 'read successfully with IO'
    end

    context 'when db trace exists' do
      before do
        build.send(:write_attribute, :trace, "data")
      end

      it_behaves_like 'read successfully with StringIO'
    end

    context 'when no sources exist' do
      it_behaves_like 'failed to read'
    end
  end

  describe 'trace handling' do
    subject { trace.exist? }

    context 'trace does not exist' do
      it { expect(trace.exist?).to be(false) }
    end

    context 'when trace artifact exists' do
      before do
        create(:ci_job_artifact, :trace, job: build)
      end

      it { is_expected.to be_truthy }

      context 'when the trace artifact has been erased' do
        before do
          trace.erase!
        end

        it { is_expected.to be_falsy }

        it 'removes associations' do
          expect(Ci::JobArtifact.exists?(job_id: build.id, file_type: :trace)).to be_falsy
        end
      end
    end

    context 'new trace path is used' do
      before do
        trace.send(:ensure_directory)

        File.open(trace.send(:default_path), "w") do |file|
          file.write("data")
        end
      end

      it "trace exist" do
        expect(trace.exist?).to be(true)
      end

      it "can be erased" do
        trace.erase!
        expect(trace.exist?).to be(false)
      end
    end

    context 'stored in database' do
      before do
        build.send(:write_attribute, :trace, "data")
      end

      it "trace exist" do
        expect(trace.exist?).to be(true)
      end

      it "can be erased" do
        trace.erase!
        expect(trace.exist?).to be(false)
      end

      it "returns database data" do
        expect(trace.raw).to eq("data")
      end
    end
  end

  describe '#archive!' do
    subject { trace.archive! }

    shared_examples 'archive trace file' do
      it do
        expect { subject }.to change { Ci::JobArtifact.count }.by(1)

        build.reload
        expect(build.trace.exist?).to be_truthy
        expect(build.job_artifacts_trace.file.exists?).to be_truthy
        expect(build.job_artifacts_trace.file.filename).to eq('job.log')
        expect(File.exist?(src_path)).to be_falsy
        expect(src_checksum)
          .to eq(Digest::SHA256.file(build.job_artifacts_trace.file.path).hexdigest)
        expect(build.job_artifacts_trace.file_sha256).to eq(src_checksum)
      end
    end

    shared_examples 'source trace file stays intact' do |error:|
      it do
        expect { subject }.to raise_error(error)

        build.reload
        expect(build.trace.exist?).to be_truthy
        expect(build.job_artifacts_trace).to be_nil
        expect(File.exist?(src_path)).to be_truthy
      end
    end

    shared_examples 'archive trace in database' do
      it do
        expect { subject }.to change { Ci::JobArtifact.count }.by(1)

        build.reload
        expect(build.trace.exist?).to be_truthy
        expect(build.job_artifacts_trace.file.exists?).to be_truthy
        expect(build.job_artifacts_trace.file.filename).to eq('job.log')
        expect(build.old_trace).to be_nil
        expect(src_checksum)
          .to eq(Digest::SHA256.file(build.job_artifacts_trace.file.path).hexdigest)
        expect(build.job_artifacts_trace.file_sha256).to eq(src_checksum)
      end
    end

    shared_examples 'source trace in database stays intact' do |error:|
      it do
        expect { subject }.to raise_error(error)

        build.reload
        expect(build.trace.exist?).to be_truthy
        expect(build.job_artifacts_trace).to be_nil
        expect(build.old_trace).to eq(trace_content)
      end
    end

    context 'when job does not have trace artifact' do
      context 'when trace file stored in default path' do
        let!(:build) { create(:ci_build, :success, :trace_live) }
        let!(:src_path) { trace.read { |s| s.path } }
        let!(:src_checksum) { Digest::SHA256.file(src_path).hexdigest }

        it_behaves_like 'archive trace file'

        context 'when failed to create clone file' do
          before do
            allow(IO).to receive(:copy_stream).and_return(0)
          end

          it_behaves_like 'source trace file stays intact', error: Gitlab::Ci::Trace::ArchiveError
        end

        context 'when failed to create job artifact record' do
          before do
            allow_any_instance_of(Ci::JobArtifact).to receive(:save).and_return(false)
            allow_any_instance_of(Ci::JobArtifact).to receive_message_chain(:errors, :full_messages)
              .and_return(%w[Error Error])
          end

          it_behaves_like 'source trace file stays intact', error: ActiveRecord::RecordInvalid
        end
      end

      context 'when trace is stored in database' do
        let(:build) { create(:ci_build, :success) }
        let(:trace_content) { 'Sample trace' }
        let(:src_checksum) { Digest::SHA256.hexdigest(trace_content) }

        before do
          build.update_column(:trace, trace_content)
        end

        it_behaves_like 'archive trace in database'

        context 'when failed to create clone file' do
          before do
            allow(IO).to receive(:copy_stream).and_return(0)
          end

          it_behaves_like 'source trace in database stays intact', error: Gitlab::Ci::Trace::ArchiveError
        end

        context 'when failed to create job artifact record' do
          before do
            allow_any_instance_of(Ci::JobArtifact).to receive(:save).and_return(false)
            allow_any_instance_of(Ci::JobArtifact).to receive_message_chain(:errors, :full_messages)
              .and_return(%w[Error Error])
          end

          it_behaves_like 'source trace in database stays intact', error: ActiveRecord::RecordInvalid
        end

        context 'when there is a validation error on Ci::Build' do
          before do
            allow_any_instance_of(Ci::Build).to receive(:save).and_return(false)
            allow_any_instance_of(Ci::Build).to receive_message_chain(:errors, :full_messages)
              .and_return(%w[Error Error])
          end

          context "when erase old trace with 'save'" do
            before do
              build.send(:write_attribute, :trace, nil)
              build.save
            end

            it 'old trace is not deleted' do
              build.reload
              expect(build.trace.raw).to eq(trace_content)
            end
          end

          it_behaves_like 'archive trace in database'
        end
      end
    end

    context 'when job has trace artifact' do
      before do
        create(:ci_job_artifact, :trace, job: build)
      end

      it 'does not archive' do
        expect_any_instance_of(described_class).not_to receive(:archive_stream!)
        expect { subject }.to raise_error(Gitlab::Ci::Trace::AlreadyArchivedError)
        expect(build.job_artifacts_trace.file.exists?).to be_truthy
      end
    end

    context 'when job is not finished yet' do
      let!(:build) { create(:ci_build, :running, :trace_live) }

      it 'does not archive' do
        expect_any_instance_of(described_class).not_to receive(:archive_stream!)
        expect { subject }.to raise_error('Job is not finished yet')
        expect(build.trace.exist?).to be_truthy
      end
    end
  end

  describe '#erase!' do
    subject { trace.erase! }

    context 'when it is a live trace' do
      context 'when trace is stored in database' do
        let(:build) { create(:ci_build) }

        before do
          build.update_column(:trace, 'sample trace')
        end

        it { expect(trace.raw).not_to be_nil }

        it "removes trace" do
          subject

          expect(trace.raw).to be_nil
        end
      end

      context 'when trace is stored in file storage' do
        let(:build) { create(:ci_build, :trace_live) }

        it { expect(trace.raw).not_to be_nil }

        it "removes trace" do
          subject

          expect(trace.raw).to be_nil
        end
      end
    end

    context 'when it is an archived trace' do
      let(:build) { create(:ci_build, :trace_artifact) }

      it "has trace at first" do
        expect(trace.raw).not_to be_nil
      end

      it "removes trace" do
        subject

        build.reload
        expect(trace.raw).to be_nil
      end
    end
  end
end

shared_examples_for 'trace with enabled live trace feature' do
  it_behaves_like 'common trace features'

  describe '#read' do
    shared_examples 'read successfully with IO' do
      it 'yields with source' do
        trace.read do |stream|
          expect(stream).to be_a(Gitlab::Ci::Trace::Stream)
          expect(stream.stream).to be_a(IO)
        end
      end
    end

    shared_examples 'read successfully with ChunkedIO' do
      it 'yields with source' do
        trace.read do |stream|
          expect(stream).to be_a(Gitlab::Ci::Trace::Stream)
          expect(stream.stream).to be_a(Gitlab::Ci::Trace::ChunkedIO)
        end
      end
    end

    shared_examples 'failed to read' do
      it 'yields without source' do
        trace.read do |stream|
          expect(stream).to be_a(Gitlab::Ci::Trace::Stream)
          expect(stream.stream).to be_nil
        end
      end
    end

    context 'when trace artifact exists' do
      before do
        create(:ci_job_artifact, :trace, job: build)
      end

      it_behaves_like 'read successfully with IO'
    end

    context 'when live trace exists' do
      before do
        Gitlab::Ci::Trace::ChunkedIO.new(build) do |stream|
          stream.write('abc')
        end
      end

      it_behaves_like 'read successfully with ChunkedIO'
    end

    context 'when no sources exist' do
      it_behaves_like 'failed to read'
    end
  end

  describe 'trace handling' do
    subject { trace.exist? }

    context 'trace does not exist' do
      it { expect(trace.exist?).to be(false) }
    end

    context 'when trace artifact exists' do
      before do
        create(:ci_job_artifact, :trace, job: build)
      end

      it { is_expected.to be_truthy }

      context 'when the trace artifact has been erased' do
        before do
          trace.erase!
        end

        it { is_expected.to be_falsy }

        it 'removes associations' do
          expect(Ci::JobArtifact.exists?(job_id: build.id, file_type: :trace)).to be_falsy
        end
      end
    end

    context 'stored in live trace' do
      before do
        Gitlab::Ci::Trace::ChunkedIO.new(build) do |stream|
          stream.write('abc')
        end
      end

      it "trace exist" do
        expect(trace.exist?).to be(true)
      end

      it "can be erased" do
        trace.erase!
        expect(trace.exist?).to be(false)
        expect(Ci::BuildTraceChunk.where(build: build)).not_to be_exist
      end

      it "returns live trace data" do
        expect(trace.raw).to eq("abc")
      end
    end
  end

  describe '#archive!' do
    subject { trace.archive! }

    shared_examples 'archive trace file in ChunkedIO' do
      it do
        expect { subject }.to change { Ci::JobArtifact.count }.by(1)

        build.reload
        expect(build.trace.exist?).to be_truthy
        expect(build.job_artifacts_trace.file.exists?).to be_truthy
        expect(build.job_artifacts_trace.file.filename).to eq('job.log')
        expect(Ci::BuildTraceChunk.where(build: build)).not_to be_exist
        expect(src_checksum)
          .to eq(Digest::SHA256.file(build.job_artifacts_trace.file.path).hexdigest)
        expect(build.job_artifacts_trace.file_sha256).to eq(src_checksum)
      end
    end

    shared_examples 'source trace in ChunkedIO stays intact' do |error:|
      it do
        expect { subject }.to raise_error(error)

        build.reload
        expect(build.trace.exist?).to be_truthy
        expect(build.job_artifacts_trace).to be_nil
        Gitlab::Ci::Trace::ChunkedIO.new(build) do |stream|
          expect(stream.read).to eq(trace_raw)
        end
      end
    end

    context 'when job does not have trace artifact' do
      context 'when trace is stored in ChunkedIO' do
        let!(:build) { create(:ci_build, :success, :trace_live) }
        let!(:trace_raw) { build.trace.raw }
        let!(:src_checksum) { Digest::SHA256.hexdigest(trace_raw) }

        it_behaves_like 'archive trace file in ChunkedIO'

        context 'when failed to create clone file' do
          before do
            allow(IO).to receive(:copy_stream).and_return(0)
          end

          it_behaves_like 'source trace in ChunkedIO stays intact', error: Gitlab::Ci::Trace::ArchiveError
        end

        context 'when failed to create job artifact record' do
          before do
            allow_any_instance_of(Ci::JobArtifact).to receive(:save).and_return(false)
            allow_any_instance_of(Ci::JobArtifact).to receive_message_chain(:errors, :full_messages)
              .and_return(%w[Error Error])
          end

          it_behaves_like 'source trace in ChunkedIO stays intact', error: ActiveRecord::RecordInvalid
        end
      end
    end

    context 'when job has trace artifact' do
      before do
        create(:ci_job_artifact, :trace, job: build)
      end

      it 'does not archive' do
        expect_any_instance_of(described_class).not_to receive(:archive_stream!)
        expect { subject }.to raise_error(Gitlab::Ci::Trace::AlreadyArchivedError)
        expect(build.job_artifacts_trace.file.exists?).to be_truthy
      end
    end

    context 'when job is not finished yet' do
      let!(:build) { create(:ci_build, :running, :trace_live) }

      it 'does not archive' do
        expect_any_instance_of(described_class).not_to receive(:archive_stream!)
        expect { subject }.to raise_error('Job is not finished yet')
        expect(build.trace.exist?).to be_truthy
      end
    end
  end

  describe '#erase!' do
    subject { trace.erase! }

    context 'when it is a live trace' do
      let(:build) { create(:ci_build, :trace_live) }

      it { expect(trace.raw).not_to be_nil }

      it "removes trace" do
        subject

        expect(trace.raw).to be_nil
      end
    end

    context 'when it is an archived trace' do
      let(:build) { create(:ci_build, :trace_artifact) }

      it "has trace at first" do
        expect(trace.raw).not_to be_nil
      end

      it "removes trace" do
        subject

        build.reload
        expect(trace.raw).to be_nil
      end
    end
  end
end
