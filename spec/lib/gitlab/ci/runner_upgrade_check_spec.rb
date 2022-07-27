# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::RunnerUpgradeCheck do
  using RSpec::Parameterized::TableSyntax

  describe '#check_runner_upgrade_status' do
    subject(:result) { described_class.instance.check_runner_upgrade_status(runner_version) }

    let(:gitlab_version) { '14.1.1' }
    let(:parsed_runner_version) { ::Gitlab::VersionInfo.parse(runner_version, parse_suffix: true) }

    before do
      allow(described_class.instance).to receive(:gitlab_version)
        .and_return(::Gitlab::VersionInfo.parse(gitlab_version))
    end

    context 'with failing Gitlab::Ci::RunnerReleases request' do
      let(:runner_version) { '14.1.123' }
      let(:runner_releases_double) { instance_double(Gitlab::Ci::RunnerReleases) }

      before do
        allow(Gitlab::Ci::RunnerReleases).to receive(:instance).and_return(runner_releases_double)
        allow(runner_releases_double).to receive(:releases).and_return(nil)
      end

      it 'returns :error' do
        is_expected.to eq({ error: parsed_runner_version })
      end
    end

    context 'with available_runner_releases configured' do
      before do
        url = ::Gitlab::CurrentSettings.current_application_settings.public_runner_releases_url

        WebMock.stub_request(:get, url).to_return(
          body: available_runner_releases.map { |v| { name: v } }.to_json,
          status: 200,
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      context 'with no available runner releases' do
        let(:available_runner_releases) do
          %w[]
        end

        context 'with Gitlab::VERSION set to 14.1.1' do
          let(:gitlab_version) { '14.1.1' }

          context 'with runner_version from last minor release' do
            let(:runner_version) { 'v14.0.1' }

            it 'returns :not_available' do
              is_expected.to eq({ not_available: parsed_runner_version })
            end
          end
        end
      end

      context 'up to 14.1.1' do
        let(:available_runner_releases) do
          %w[13.9.0 13.9.1 13.9.2 13.10.0 13.10.1 14.0.0 14.0.1 14.0.2-rc1 14.0.2 14.1.0 14.1.1]
        end

        context 'with nil runner_version' do
          let(:runner_version) { nil }

          it 'returns :invalid_version' do
            is_expected.to match({ invalid_version: anything })
          end
        end

        context 'with invalid runner_version' do
          let(:runner_version) { 'junk' }

          it 'returns :invalid_version' do
            is_expected.to match({ invalid_version: anything })
          end
        end

        context 'with Gitlab::VERSION set to 14.1.123' do
          let(:gitlab_version) { '14.1.123' }

          context 'with a runner_version that is too recent' do
            let(:runner_version) { 'v14.2.0' }

            it 'returns :not_available' do
              is_expected.to eq({ not_available: parsed_runner_version })
            end
          end
        end

        context 'with Gitlab::VERSION set to 14.0.1' do
          let(:gitlab_version) { '14.0.1' }

          context 'with valid params' do
            where(:runner_version, :expected_result, :expected_suggested_version) do
              'v15.0.0'                      | :not_available | '15.0.0' # not available since the GitLab instance is still on 14.x, a major version might be incompatible, and a patch upgrade is not available
              'v14.1.0-rc3'                  | :recommended   | '14.1.1' # recommended since even though the GitLab instance is still on 14.0.x, there is a patch release (14.1.1) available which might contain security fixes
              'v14.1.0~beta.1574.gf6ea9389'  | :recommended   | '14.1.1' # suffixes are correctly handled
              'v14.1.0/1.1.0'                | :recommended   | '14.1.1' # suffixes are correctly handled
              'v14.1.0'                      | :recommended   | '14.1.1' # recommended since even though the GitLab instance is still on 14.0.x, there is a patch release (14.1.1) available which might contain security fixes
              'v14.0.1'                      | :recommended   | '14.0.2' # recommended upgrade since 14.0.2 is available
              'v14.0.2-rc1'                  | :recommended   | '14.0.2' # recommended upgrade since 14.0.2 is available and we'll move out of a release candidate
              'v14.0.2'                      | :not_available | '14.0.2' # not available since 14.0.2 is the latest 14.0.x release available within the instance's major.minor version
              'v13.10.1'                     | :available     | '14.0.2' # available upgrade: 14.0.2
              'v13.10.1~beta.1574.gf6ea9389' | :recommended   | '13.10.1' # suffixes are correctly handled, official 13.10.1 is available
              'v13.10.1/1.1.0'               | :recommended   | '13.10.1' # suffixes are correctly handled, official 13.10.1 is available
              'v13.10.0'                     | :recommended   | '13.10.1' # recommended upgrade since 13.10.1 is available
              'v13.9.2'                      | :recommended   | '14.0.2' # recommended upgrade since backports are no longer released for this version
              'v13.9.0'                      | :recommended   | '14.0.2' # recommended upgrade since backports are no longer released for this version
              'v13.8.1'                      | :recommended   | '14.0.2' # recommended upgrade since build is too old (missing in records)
              'v11.4.1'                      | :recommended   | '14.0.2' # recommended upgrade since build is too old (missing in records)
            end

            with_them do
              it { is_expected.to eq({ expected_result => Gitlab::VersionInfo.parse(expected_suggested_version) }) }
            end
          end
        end

        context 'with Gitlab::VERSION set to 13.9.0' do
          let(:gitlab_version) { '13.9.0' }

          context 'with valid params' do
            where(:runner_version, :expected_result, :expected_suggested_version) do
              'v14.0.0'                      | :recommended   | '14.0.2'  # recommended upgrade since 14.0.2 is available, even though the GitLab instance is still on 13.x and a major version might be incompatible
              'v13.10.1'                     | :not_available | '13.10.1' # not available since 13.10.1 is already ahead of GitLab instance version and is the latest patch update for 13.10.x
              'v13.10.0'                     | :recommended   | '13.10.1' # recommended upgrade since 13.10.1 is available
              'v13.9.2'                      | :not_available | '13.9.2'  # not_available even though backports are no longer released for this version because the runner is already on the same version as the GitLab version
              'v13.9.0'                      | :recommended   | '13.9.2'  # recommended upgrade since backports are no longer released for this version
              'v13.8.1'                      | :recommended   | '13.9.2'  # recommended upgrade since build is too old (missing in records)
              'v11.4.1'                      | :recommended   | '13.9.2'  # recommended upgrade since build is too old (missing in records)
            end

            with_them do
              it { is_expected.to eq({ expected_result => Gitlab::VersionInfo.parse(expected_suggested_version) }) }
            end
          end
        end
      end

      context 'up to 15.1.0' do
        let(:available_runner_releases) { %w[14.9.1 14.9.2 14.10.0 14.10.1 15.0.0 15.1.0] }

        context 'with Gitlab::VERSION set to 15.2.0-pre' do
          let(:gitlab_version) { '15.2.0-pre' }

          context 'with unknown runner version' do
            let(:runner_version) { '14.11.0~beta.29.gd0c550e3' }

            it 'recommends 15.1.0 since 14.11 is an unknown release and 15.1.0 is available' do
              is_expected.to eq({ recommended: Gitlab::VersionInfo.new(15, 1, 0) })
            end
          end
        end
      end
    end
  end
end
