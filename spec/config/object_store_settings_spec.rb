# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('config', 'object_store_settings.rb')

RSpec.describe ObjectStoreSettings do
  describe '#parse!' do
    let(:settings) { Settingslogic.new(config) }

    subject { described_class.new(settings).parse! }

    context 'with valid config' do
      let(:connection) do
        {
          'provider' => 'AWS',
          'aws_access_key_id' => 'AWS_ACCESS_KEY_ID',
          'aws_secret_access_key' => 'AWS_SECRET_ACCESS_KEY',
          'region' => 'us-east-1'
        }
      end

      let(:config) do
        {
          'lfs' => { 'enabled' => true },
          'artifacts' => { 'enabled' => true },
          'external_diffs' => { 'enabled' => false },
          'pages' => { 'enabled' => true },
          'object_store' => {
            'enabled' => true,
            'connection' => connection,
            'proxy_download' => true,
            'objects' => {
              'artifacts' => {
                'bucket' => 'artifacts',
                'proxy_download' => false
              },
              'lfs' => {
                'bucket' => 'lfs-objects'
              },
              'external_diffs' => {
                'bucket' => 'external_diffs',
                'enabled' => false
              },
              'pages' => {
                'bucket' => 'pages'
              }
            }
          }
        }
      end

      shared_examples 'consolidated settings for objects accelerated by Workhorse' do
        it 'consolidates active object storage settings' do
          described_class::WORKHORSE_ACCELERATED_TYPES.each do |object_type|
            # Use to_h to avoid https://gitlab.com/gitlab-org/gitlab/-/issues/286873
            section = subject.try(object_type).to_h

            next unless section.dig('object_store', 'enabled')

            expect(section['object_store']['connection']).to eq(connection)
            expect(section['object_store']['consolidated_settings']).to be true
          end
        end
      end

      it 'sets correct default values' do
        subject

        expect(settings.artifacts['enabled']).to be true
        expect(settings.artifacts['object_store']['enabled']).to be true
        expect(settings.artifacts['object_store']['connection']).to eq(connection)
        expect(settings.artifacts['object_store']['direct_upload']).to be true
        expect(settings.artifacts['object_store']['background_upload']).to be false
        expect(settings.artifacts['object_store']['proxy_download']).to be false
        expect(settings.artifacts['object_store']['remote_directory']).to eq('artifacts')
        expect(settings.artifacts['object_store']['bucket_prefix']).to eq(nil)
        expect(settings.artifacts['object_store']['consolidated_settings']).to be true
        expect(settings.artifacts).to eq(settings['artifacts'])

        expect(settings.lfs['enabled']).to be true
        expect(settings.lfs['object_store']['enabled']).to be true
        expect(settings.lfs['object_store']['connection']).to eq(connection)
        expect(settings.lfs['object_store']['direct_upload']).to be true
        expect(settings.lfs['object_store']['background_upload']).to be false
        expect(settings.lfs['object_store']['proxy_download']).to be true
        expect(settings.lfs['object_store']['remote_directory']).to eq('lfs-objects')
        expect(settings.lfs['object_store']['bucket_prefix']).to eq(nil)
        expect(settings.lfs['object_store']['consolidated_settings']).to be true
        expect(settings.lfs).to eq(settings['lfs'])

        expect(settings.pages['enabled']).to be true
        expect(settings.pages['object_store']['enabled']).to be true
        expect(settings.pages['object_store']['connection']).to eq(connection)
        expect(settings.pages['object_store']['remote_directory']).to eq('pages')
        expect(settings.pages['object_store']['bucket_prefix']).to eq(nil)
        expect(settings.pages['object_store']['consolidated_settings']).to be true
        expect(settings.pages).to eq(settings['pages'])

        expect(settings.external_diffs['enabled']).to be false
        expect(settings.external_diffs['object_store']).to be_nil
        expect(settings.external_diffs).to eq(settings['external_diffs'])
      end

      it 'supports bucket prefixes' do
        config['object_store']['objects']['artifacts']['bucket'] = 'gitlab/artifacts'
        config['object_store']['objects']['lfs']['bucket'] = 'gitlab/lfs'

        subject

        expect(settings.artifacts['object_store']['remote_directory']).to eq('gitlab')
        expect(settings.artifacts['object_store']['bucket_prefix']).to eq('artifacts')
        expect(settings.lfs['object_store']['remote_directory']).to eq('gitlab')
        expect(settings.lfs['object_store']['bucket_prefix']).to eq('lfs')
      end

      it 'raises an error when a bucket is missing' do
        config['object_store']['objects']['lfs'].delete('bucket')

        expect { subject }.to raise_error(/Object storage for lfs must have a bucket specified/)
      end

      it 'does not raise error if pages bucket is missing' do
        config['object_store']['objects']['pages'].delete('bucket')

        expect { subject }.not_to raise_error
        expect(settings.pages['object_store']).to eq(nil)
      end

      context 'GitLab Pages' do
        let(:pages_connection) { { 'provider' => 'Google', 'google_application_default' => true } }

        before do
          config['pages'] = {
            'enabled' => true,
            'object_store' => {
              'enabled' => true,
              'connection' => pages_connection
            }
          }
        end

        it_behaves_like 'consolidated settings for objects accelerated by Workhorse'

        it 'allows pages to define its own connection' do
          expect { subject }.not_to raise_error

          expect(settings.pages['object_store']['connection']).to eq(pages_connection)
          expect(settings.pages['object_store']['consolidated_settings']).to be_falsey
        end
      end

      context 'when object storage is disabled for artifacts with no bucket' do
        before do
          config['artifacts'] = {
            'enabled' => true,
            'object_store' => {}
          }
          config['object_store']['objects']['artifacts'] = {
            'enabled' => false
          }
        end

        it_behaves_like 'consolidated settings for objects accelerated by Workhorse'

        it 'does not enable consolidated settings for artifacts' do
          subject

          expect(settings.artifacts['enabled']).to be true
          expect(settings.artifacts['object_store']['remote_directory']).to be_nil
          expect(settings.artifacts['object_store']['bucket_prefix']).to be_nil
          expect(settings.artifacts['object_store']['enabled']).to be_falsey
          expect(settings.artifacts['object_store']['consolidated_settings']).to be_falsey
        end
      end

      context 'with legacy config' do
        let(:legacy_settings) do
          {
            'enabled' => true,
            'remote_directory' => 'some-bucket',
            'direct_upload' => false,
            'background_upload' => true,
            'proxy_download' => false
          }
        end

        before do
          settings.lfs['object_store'] = described_class.legacy_parse(legacy_settings, 'lfs')
        end

        it 'does not alter config if legacy settings are specified' do
          subject

          expect(settings.artifacts['object_store']).to be_nil
          expect(settings.lfs['object_store']['remote_directory']).to eq('some-bucket')
          expect(settings.lfs['object_store']['bucket_prefix']).to eq(nil)
          # Disable background_upload, regardless of the input config
          expect(settings.lfs['object_store']['direct_upload']).to eq(true)
          expect(settings.lfs['object_store']['background_upload']).to eq(false)
          expect(settings.external_diffs['object_store']).to be_nil
        end
      end

      context 'with legacy config and legacy background upload is enabled' do
        let(:legacy_settings) do
          {
            'enabled' => true,
            'remote_directory' => 'some-bucket',
            'proxy_download' => false
          }
        end

        before do
          stub_env(ObjectStoreSettings::LEGACY_BACKGROUND_UPLOADS_ENV, 'lfs')
          settings.lfs['object_store'] = described_class.legacy_parse(legacy_settings, 'lfs')
        end

        it 'enables background_upload and disables direct_upload' do
          subject

          expect(settings.artifacts['object_store']).to be_nil
          expect(settings.lfs['object_store']['remote_directory']).to eq('some-bucket')
          expect(settings.lfs['object_store']['bucket_prefix']).to eq(nil)
          # Enable background_upload if the environment variable is available
          expect(settings.lfs['object_store']['direct_upload']).to eq(false)
          expect(settings.lfs['object_store']['background_upload']).to eq(true)
          expect(settings.external_diffs['object_store']).to be_nil
        end
      end
    end
  end

  describe '.legacy_parse' do
    it 'sets correct default values' do
      settings = described_class.legacy_parse(nil, 'artifacts')

      expect(settings['enabled']).to be false
      expect(settings['direct_upload']).to be true
      expect(settings['background_upload']).to be false
      expect(settings['remote_directory']).to be nil
      expect(settings['bucket_prefix']).to be nil
    end

    it 'respects original values' do
      original_settings = Settingslogic.new({
        'enabled' => true,
        'remote_directory' => 'artifacts'
      })

      settings = described_class.legacy_parse(original_settings, 'artifacts')

      expect(settings['enabled']).to be true
      expect(settings['direct_upload']).to be true
      expect(settings['background_upload']).to be false
      expect(settings['remote_directory']).to eq 'artifacts'
      expect(settings['bucket_prefix']).to be nil
    end

    it 'supports bucket prefixes' do
      original_settings = Settingslogic.new({
        'enabled' => true,
        'remote_directory' => 'gitlab/artifacts'
      })

      settings = described_class.legacy_parse(original_settings, 'artifacts')
      expect(settings['remote_directory']).to eq 'gitlab'
      expect(settings['bucket_prefix']).to eq 'artifacts'
    end

    context 'legacy background upload environment variable is enabled' do
      before do
        stub_env(ObjectStoreSettings::LEGACY_BACKGROUND_UPLOADS_ENV, 'artifacts,lfs')
      end

      it 'enables background_upload and disables direct_upload' do
        original_settings = Settingslogic.new({
          'enabled' => true,
          'remote_directory' => 'artifacts'
        })

        settings = described_class.legacy_parse(original_settings, 'artifacts')

        expect(settings['enabled']).to be true
        expect(settings['direct_upload']).to be false
        expect(settings['background_upload']).to be true
        expect(settings['remote_directory']).to eq 'artifacts'
        expect(settings['bucket_prefix']).to eq nil
      end
    end

    context 'legacy background upload environment variable is enabled for other types' do
      before do
        stub_env(ObjectStoreSettings::LEGACY_BACKGROUND_UPLOADS_ENV, 'uploads,lfs')
      end

      it 'enables direct_upload and disables background_upload' do
        original_settings = Settingslogic.new({
          'enabled' => true,
          'remote_directory' => 'artifacts'
        })

        settings = described_class.legacy_parse(original_settings, 'artifacts')

        expect(settings['enabled']).to be true
        expect(settings['direct_upload']).to be true
        expect(settings['background_upload']).to be false
        expect(settings['remote_directory']).to eq 'artifacts'
        expect(settings['bucket_prefix']).to eq nil
      end
    end
  end

  describe '.split_bucket_prefix' do
    using RSpec::Parameterized::TableSyntax

    subject { described_class.split_bucket_prefix(input) }

    context 'valid inputs' do
      where(:input, :bucket, :prefix) do
        nil | nil | nil
        '' | nil | nil
        'bucket' | 'bucket' | nil
        'bucket/prefix' | 'bucket' | 'prefix'
        'bucket/pre/fix' | 'bucket' | 'pre/fix'
      end

      with_them do
        it { expect(subject).to eq([bucket, prefix]) }
      end
    end

    context 'invalid inputs' do
      where(:input) do
        [
          ['bucket/'],
          ['bucket/.'],
          ['bucket/..'],
          ['bucket/prefix/'],
          ['bucket/prefix/.'],
          ['bucket/prefix/..'],
          ['/bucket/prefix'],
          ['./bucket/prefix'],
          ['../bucket/prefix'],
          ['bucket//prefix'],
          ['bucket/./prefix'],
          ['bucket/../prefix']
        ]
      end

      with_them do
        it { expect { subject }.to raise_error(/invalid bucket/) }
      end
    end
  end
end
