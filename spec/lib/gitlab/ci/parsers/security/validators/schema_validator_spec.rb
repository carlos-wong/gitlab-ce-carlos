# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Parsers::Security::Validators::SchemaValidator do
  let_it_be(:project) { create(:project) }

  let(:scanner) do
    {
      'id' => 'gemnasium',
      'name' => 'Gemnasium',
      'version' => '2.1.0'
    }
  end

  let(:validator) { described_class.new(report_type, report_data, report_version, project: project, scanner: scanner) }

  describe 'SUPPORTED_VERSIONS' do
    schema_path = Rails.root.join("lib", "gitlab", "ci", "parsers", "security", "validators", "schemas")

    it 'matches DEPRECATED_VERSIONS keys' do
      expect(described_class::SUPPORTED_VERSIONS.keys).to eq(described_class::DEPRECATED_VERSIONS.keys)
    end

    context 'files under schema path are explicitly listed' do
      # We only care about the part that comes before report-format.json
      # https://rubular.com/r/N8Juz7r8hYDYgD
      filename_regex = /(?<report_type>[-\w]*)\-report-format.json/

      versions = Dir.glob(File.join(schema_path, "*", File::SEPARATOR)).map { |path| path.split("/").last }

      versions.each do |version|
        files = Dir[schema_path.join(version, "*.json")]

        files.each do |file|
          matches = filename_regex.match(file)
          report_type = matches[:report_type].tr("-", "_").to_sym

          it "#{report_type} #{version}" do
            expect(described_class::SUPPORTED_VERSIONS[report_type]).to include(version)
          end
        end
      end
    end

    context 'every SUPPORTED_VERSION has a corresponding JSON file' do
      described_class::SUPPORTED_VERSIONS.each_key do |report_type|
        # api_fuzzing is covered by DAST schema
        next if report_type == :api_fuzzing

        described_class::SUPPORTED_VERSIONS[report_type].each do |version|
          it "#{report_type} #{version} schema file is present" do
            filename = "#{report_type.to_s.tr("_", "-")}-report-format.json"
            full_path = schema_path.join(version, filename)
            expect(File.file?(full_path)).to be true
          end
        end
      end
    end
  end

  describe '#valid?' do
    subject { validator.valid? }

    context 'when given a supported schema version' do
      let(:report_type) { :dast }
      let(:report_version) { described_class::SUPPORTED_VERSIONS[report_type].last }

      context 'and the report is valid' do
        let(:report_data) do
          {
            'version' => report_version,
            'vulnerabilities' => []
          }
        end

        it { is_expected.to be_truthy }
      end

      context 'and the report is invalid' do
        let(:report_data) do
          {
            'version' => report_version
          }
        end

        it { is_expected.to be_falsey }

        it 'logs related information' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            message: "security report schema validation problem",
            security_report_type: report_type,
            security_report_version: report_version,
            project_id: project.id,
            security_report_failure: 'schema_validation_fails',
            security_report_scanner_id: 'gemnasium',
            security_report_scanner_version: '2.1.0'
          )

          subject
        end
      end
    end

    context 'when given a deprecated schema version' do
      let(:report_type) { :dast }
      let(:report_version) { described_class::DEPRECATED_VERSIONS[report_type].last }

      context 'and the report passes schema validation' do
        let(:report_data) do
          {
            'version' => '10.0.0',
            'vulnerabilities' => []
          }
        end

        it { is_expected.to be_truthy }

        it 'logs related information' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            message: "security report schema validation problem",
            security_report_type: report_type,
            security_report_version: report_version,
            project_id: project.id,
            security_report_failure: 'using_deprecated_schema_version',
            security_report_scanner_id: 'gemnasium',
            security_report_scanner_version: '2.1.0'
          )

          subject
        end
      end

      context 'and the report does not pass schema validation' do
        context 'and enforce_security_report_validation is enabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: true)
          end

          let(:report_data) do
            {
              'version' => 'V2.7.0'
            }
          end

          it { is_expected.to be_falsey }
        end

        context 'and enforce_security_report_validation is disabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: false)
          end

          let(:report_data) do
            {
              'version' => 'V2.7.0'
            }
          end

          it { is_expected.to be_truthy }
        end
      end
    end

    context 'when given an unsupported schema version' do
      let(:report_type) { :dast }
      let(:report_version) { "12.37.0" }

      context 'if enforce_security_report_validation is enabled' do
        before do
          stub_feature_flags(enforce_security_report_validation: true)
        end

        context 'and the report is valid' do
          let(:report_data) do
            {
              'version' => report_version,
              'vulnerabilities' => []
            }
          end

          it { is_expected.to be_falsey }

          it 'logs related information' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              message: "security report schema validation problem",
              security_report_type: report_type,
              security_report_version: report_version,
              project_id: project.id,
              security_report_failure: 'using_unsupported_schema_version',
              security_report_scanner_id: 'gemnasium',
              security_report_scanner_version: '2.1.0'
            )

            subject
          end
        end

        context 'and the report is invalid' do
          let(:report_data) do
            {
              'version' => report_version
            }
          end

          context 'and scanner information is empty' do
            let(:scanner) { {} }

            it 'logs related information' do
              expect(Gitlab::AppLogger).to receive(:info).with(
                message: "security report schema validation problem",
                security_report_type: report_type,
                security_report_version: report_version,
                project_id: project.id,
                security_report_failure: 'schema_validation_fails',
                security_report_scanner_id: nil,
                security_report_scanner_version: nil
              )

              expect(Gitlab::AppLogger).to receive(:info).with(
                message: "security report schema validation problem",
                security_report_type: report_type,
                security_report_version: report_version,
                project_id: project.id,
                security_report_failure: 'using_unsupported_schema_version',
                security_report_scanner_id: nil,
                security_report_scanner_version: nil
              )

              subject
            end
          end

          it { is_expected.to be_falsey }
        end
      end

      context 'if enforce_security_report_validation is disabled' do
        before do
          stub_feature_flags(enforce_security_report_validation: false)
        end

        context 'and the report is valid' do
          let(:report_data) do
            {
              'version' => report_version,
              'vulnerabilities' => []
            }
          end

          it { is_expected.to be_truthy }
        end

        context 'and the report is invalid' do
          let(:report_data) do
            {
              'version' => report_version
            }
          end

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#errors' do
    subject { validator.errors }

    context 'when given a supported schema version' do
      let(:report_type) { :dast }
      let(:report_version) { described_class::SUPPORTED_VERSIONS[report_type].last }

      context 'and the report is valid' do
        let(:report_data) do
          {
            'version' => report_version,
            'vulnerabilities' => []
          }
        end

        let(:expected_errors) { [] }

        it { is_expected.to match_array(expected_errors) }
      end

      context 'and the report is invalid' do
        let(:report_data) do
          {
            'version' => report_version
          }
        end

        context 'if enforce_security_report_validation is enabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: project)
          end

          let(:expected_errors) do
            [
              'root is missing required keys: vulnerabilities'
            ]
          end

          it { is_expected.to match_array(expected_errors) }
        end

        context 'if enforce_security_report_validation is disabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: false)
          end

          let(:expected_errors) { [] }

          it { is_expected.to match_array(expected_errors) }
        end
      end
    end

    context 'when given a deprecated schema version' do
      let(:report_type) { :dast }
      let(:report_version) { described_class::DEPRECATED_VERSIONS[report_type].last }

      context 'and the report passes schema validation' do
        let(:report_data) do
          {
            'version' => '10.0.0',
            'vulnerabilities' => []
          }
        end

        let(:expected_errors) { [] }

        it { is_expected.to match_array(expected_errors) }
      end

      context 'and the report does not pass schema validation' do
        context 'and enforce_security_report_validation is enabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: true)
          end

          let(:report_data) do
            {
              'version' => 'V2.7.0'
            }
          end

          let(:expected_errors) do
            [
              "property '/version' does not match pattern: ^[0-9]+\\.[0-9]+\\.[0-9]+$",
              "root is missing required keys: vulnerabilities"
            ]
          end

          it { is_expected.to match_array(expected_errors) }
        end

        context 'and enforce_security_report_validation is disabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: false)
          end

          let(:report_data) do
            {
              'version' => 'V2.7.0'
            }
          end

          let(:expected_errors) { [] }

          it { is_expected.to match_array(expected_errors) }
        end
      end
    end

    context 'when given an unsupported schema version' do
      let(:report_type) { :dast }
      let(:report_version) { "12.37.0" }

      context 'if enforce_security_report_validation is enabled' do
        before do
          stub_feature_flags(enforce_security_report_validation: true)
        end

        context 'and the report is valid' do
          let(:report_data) do
            {
              'version' => report_version,
              'vulnerabilities' => []
            }
          end

          let(:expected_errors) do
            [
              "Version 12.37.0 for report type dast is unsupported, supported versions for this report type are: 14.0.0, 14.0.1, 14.0.2, 14.0.3, 14.0.4, 14.0.5, 14.0.6, 14.1.0, 14.1.1"
            ]
          end

          it { is_expected.to match_array(expected_errors) }
        end

        context 'and the report is invalid' do
          let(:report_data) do
            {
              'version' => report_version
            }
          end

          let(:expected_errors) do
            [
              "Version 12.37.0 for report type dast is unsupported, supported versions for this report type are: 14.0.0, 14.0.1, 14.0.2, 14.0.3, 14.0.4, 14.0.5, 14.0.6, 14.1.0, 14.1.1",
              "root is missing required keys: vulnerabilities"
            ]
          end

          it { is_expected.to match_array(expected_errors) }
        end
      end

      context 'if enforce_security_report_validation is disabled' do
        before do
          stub_feature_flags(enforce_security_report_validation: false)
        end

        context 'and the report is valid' do
          let(:report_data) do
            {
              'version' => report_version,
              'vulnerabilities' => []
            }
          end

          let(:expected_errors) { [] }

          it { is_expected.to match_array(expected_errors) }
        end

        context 'and the report is invalid' do
          let(:report_data) do
            {
              'version' => report_version
            }
          end

          let(:expected_errors) { [] }

          it { is_expected.to match_array(expected_errors) }
        end
      end
    end
  end

  describe '#deprecation_warnings' do
    subject { validator.deprecation_warnings }

    context 'when given a supported schema version' do
      let(:report_type) { :dast }
      let(:report_version) { described_class::SUPPORTED_VERSIONS[report_type].last }

      let(:expected_deprecation_warnings) { [] }

      context 'and the report is valid' do
        let(:report_data) do
          {
            'version' => report_version,
            'vulnerabilities' => []
          }
        end

        it { is_expected.to match_array(expected_deprecation_warnings) }
      end

      context 'and the report is invalid' do
        let(:report_data) do
          {
            'version' => report_version
          }
        end

        it { is_expected.to match_array(expected_deprecation_warnings) }
      end
    end

    context 'when given a deprecated schema version' do
      let(:report_type) { :dast }
      let(:report_version) { described_class::DEPRECATED_VERSIONS[report_type].last }
      let(:expected_deprecation_warnings) do
        [
          "Version V2.7.0 for report type dast has been deprecated, supported versions for this report type are: 14.0.0, 14.0.1, 14.0.2, 14.0.3, 14.0.4, 14.0.5, 14.0.6, 14.1.0, 14.1.1"
        ]
      end

      context 'and the report passes schema validation' do
        let(:report_data) do
          {
            'version' => report_version,
            'vulnerabilities' => []
          }
        end

        it { is_expected.to match_array(expected_deprecation_warnings) }
      end

      context 'and the report does not pass schema validation' do
        let(:report_data) do
          {
            'version' => 'V2.7.0'
          }
        end

        it { is_expected.to match_array(expected_deprecation_warnings) }
      end
    end

    context 'when given an unsupported schema version' do
      let(:report_type) { :dast }
      let(:report_version) { "21.37.0" }
      let(:expected_deprecation_warnings) { [] }
      let(:report_data) do
        {
          'version' => report_version,
          'vulnerabilities' => []
        }
      end

      it { is_expected.to match_array(expected_deprecation_warnings) }
    end
  end

  describe '#warnings' do
    subject { validator.warnings }

    context 'when given a supported schema version' do
      let(:report_type) { :dast }
      let(:report_version) { described_class::SUPPORTED_VERSIONS[report_type].last }

      context 'and the report is valid' do
        let(:report_data) do
          {
            'version' => report_version,
            'vulnerabilities' => []
          }
        end

        let(:expected_warnings) { [] }

        it { is_expected.to match_array(expected_warnings) }
      end

      context 'and the report is invalid' do
        let(:report_data) do
          {
            'version' => report_version
          }
        end

        context 'if enforce_security_report_validation is enabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: project)
          end

          let(:expected_warnings) { [] }

          it { is_expected.to match_array(expected_warnings) }
        end

        context 'if enforce_security_report_validation is disabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: false)
          end

          let(:expected_warnings) do
            [
              'root is missing required keys: vulnerabilities'
            ]
          end

          it { is_expected.to match_array(expected_warnings) }
        end
      end
    end

    context 'when given a deprecated schema version' do
      let(:report_type) { :dast }
      let(:report_version) { described_class::DEPRECATED_VERSIONS[report_type].last }

      context 'and the report passes schema validation' do
        let(:report_data) do
          {
            'vulnerabilities' => []
          }
        end

        let(:expected_warnings) { [] }

        it { is_expected.to match_array(expected_warnings) }
      end

      context 'and the report does not pass schema validation' do
        let(:report_data) do
          {
            'version' => 'V2.7.0'
          }
        end

        context 'and enforce_security_report_validation is enabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: true)
          end

          let(:expected_warnings) { [] }

          it { is_expected.to match_array(expected_warnings) }
        end

        context 'and enforce_security_report_validation is disabled' do
          before do
            stub_feature_flags(enforce_security_report_validation: false)
          end

          let(:expected_warnings) do
            [
              "property '/version' does not match pattern: ^[0-9]+\\.[0-9]+\\.[0-9]+$",
              "root is missing required keys: vulnerabilities"
            ]
          end

          it { is_expected.to match_array(expected_warnings) }
        end
      end
    end

    context 'when given an unsupported schema version' do
      let(:report_type) { :dast }
      let(:report_version) { "12.37.0" }

      context 'if enforce_security_report_validation is enabled' do
        before do
          stub_feature_flags(enforce_security_report_validation: true)
        end

        context 'and the report is valid' do
          let(:report_data) do
            {
              'version' => report_version,
              'vulnerabilities' => []
            }
          end

          let(:expected_warnings) { [] }

          it { is_expected.to match_array(expected_warnings) }
        end

        context 'and the report is invalid' do
          let(:report_data) do
            {
              'version' => report_version
            }
          end

          let(:expected_warnings) { [] }

          it { is_expected.to match_array(expected_warnings) }
        end
      end

      context 'if enforce_security_report_validation is disabled' do
        before do
          stub_feature_flags(enforce_security_report_validation: false)
        end

        context 'and the report is valid' do
          let(:report_data) do
            {
              'version' => report_version,
              'vulnerabilities' => []
            }
          end

          let(:expected_warnings) do
            [
              "Version 12.37.0 for report type dast is unsupported, supported versions for this report type are: 14.0.0, 14.0.1, 14.0.2, 14.0.3, 14.0.4, 14.0.5, 14.0.6, 14.1.0, 14.1.1"
            ]
          end

          it { is_expected.to match_array(expected_warnings) }
        end

        context 'and the report is invalid' do
          let(:report_data) do
            {
              'version' => report_version
            }
          end

          let(:expected_warnings) do
            [
              "Version 12.37.0 for report type dast is unsupported, supported versions for this report type are: 14.0.0, 14.0.1, 14.0.2, 14.0.3, 14.0.4, 14.0.5, 14.0.6, 14.1.0, 14.1.1",
              "root is missing required keys: vulnerabilities"
            ]
          end

          it { is_expected.to match_array(expected_warnings) }
        end
      end
    end
  end
end
