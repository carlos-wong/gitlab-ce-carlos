# frozen_string_literal: true

require 'fast_spec_helper'
require 'rspec-parameterized'

require_relative '../../support/stub_settings_source'
require_relative '../../../sidekiq_cluster/cli'
require_relative '../../support/helpers/next_instance_of'

RSpec.describe Gitlab::SidekiqCluster::CLI, stub_settings_source: true do # rubocop:disable RSpec/FilePath
  include NextInstanceOf

  let(:cli) { described_class.new('/dev/null') }
  let(:timeout) { Gitlab::SidekiqCluster::DEFAULT_SOFT_TIMEOUT_SECONDS }
  let(:default_options) do
    { env: 'test', directory: Dir.pwd, max_concurrency: 50, min_concurrency: 0, dryrun: false, timeout: timeout }
  end

  let(:sidekiq_exporter_enabled) { false }
  let(:sidekiq_exporter_port) { '3807' }
  let(:sidekiq_health_checks_port) { '3807' }

  let(:config_file) { Tempfile.new('gitlab.yml') }
  let(:config) do
    {
      'test' => {
        'monitoring' => {
          'sidekiq_exporter' => {
            'address' => 'localhost',
            'enabled' => sidekiq_exporter_enabled,
            'port' => sidekiq_exporter_port
          },
          'sidekiq_health_checks' => {
            'address' => 'localhost',
            'enabled' => sidekiq_exporter_enabled,
            'port' => sidekiq_health_checks_port
          }
        }
      }
    }
  end

  let(:supervisor) { instance_double(Gitlab::SidekiqCluster::SidekiqProcessSupervisor) }
  let(:metrics_cleanup_service) { instance_double(Prometheus::CleanupMultiprocDirService, execute: nil) }

  before do
    stub_env('RAILS_ENV', 'test')

    config_file.write(YAML.dump(config))
    config_file.close

    allow(::Settings).to receive(:source).and_return(config_file.path)
    ::Settings.reload!

    allow(Gitlab::ProcessManagement).to receive(:write_pid)
    allow(Gitlab::SidekiqCluster::SidekiqProcessSupervisor).to receive(:instance).and_return(supervisor)
    allow(supervisor).to receive(:supervise)

    allow(Prometheus::CleanupMultiprocDirService).to receive(:new).and_return(metrics_cleanup_service)
  end

  after do
    config_file.unlink
  end

  describe '#run' do
    context 'without any arguments' do
      it 'raises CommandError' do
        expect { cli.run([]) }.to raise_error(described_class::CommandError)
      end
    end

    context 'with arguments' do
      it 'starts the Sidekiq workers' do
        expect(Gitlab::SidekiqCluster).to receive(:start)
                                            .with([['foo']], default_options)
                                            .and_return([])

        cli.run(%w(foo))
      end

      it 'allows the special * selector' do
        worker_queues = %w(foo bar baz)

        expect(Gitlab::SidekiqConfig::CliMethods)
          .to receive(:worker_queues).and_return(worker_queues)

        expect(Gitlab::SidekiqCluster)
          .to receive(:start).with([worker_queues], default_options).and_return([])

        cli.run(%w(*))
      end

      it 'raises an error when the arguments contain newlines' do
        invalid_arguments = [
          ["foo\n"],
          ["foo\r"],
          %W[foo b\nar]
        ]

        invalid_arguments.each do |arguments|
          expect { cli.run(arguments) }.to raise_error(described_class::CommandError)
        end
      end

      context 'with --negate flag' do
        it 'starts Sidekiq workers for all queues in all_queues.yml except the ones in argv' do
          expect(Gitlab::SidekiqConfig::CliMethods).to receive(:worker_queues).and_return(['baz'])
          expect(Gitlab::SidekiqCluster).to receive(:start)
                                              .with([['baz']], default_options)
                                              .and_return([])

          cli.run(%w(foo -n))
        end
      end

      context 'with --max-concurrency flag' do
        it 'starts Sidekiq workers for specified queues with a max concurrency' do
          expect(Gitlab::SidekiqConfig::CliMethods).to receive(:worker_queues).and_return(%w(foo bar baz))
          expect(Gitlab::SidekiqCluster).to receive(:start)
                                              .with([%w(foo bar baz), %w(solo)], default_options.merge(max_concurrency: 2))
                                              .and_return([])

          cli.run(%w(foo,bar,baz solo -m 2))
        end
      end

      context 'with --min-concurrency flag' do
        it 'starts Sidekiq workers for specified queues with a min concurrency' do
          expect(Gitlab::SidekiqConfig::CliMethods).to receive(:worker_queues).and_return(%w(foo bar baz))
          expect(Gitlab::SidekiqCluster).to receive(:start)
                                              .with([%w(foo bar baz), %w(solo)], default_options.merge(min_concurrency: 2))
                                              .and_return([])

          cli.run(%w(foo,bar,baz solo --min-concurrency 2))
        end
      end

      context 'with --timeout flag' do
        it 'when given', 'starts Sidekiq workers with given timeout' do
          expect(Gitlab::SidekiqCluster).to receive(:start)
            .with([['foo']], default_options.merge(timeout: 10))
            .and_return([])

          cli.run(%w(foo --timeout 10))
        end

        it 'when not given', 'starts Sidekiq workers with default timeout' do
          expect(Gitlab::SidekiqCluster).to receive(:start)
            .with([['foo']], default_options.merge(timeout: Gitlab::SidekiqCluster::DEFAULT_SOFT_TIMEOUT_SECONDS))
            .and_return([])

          cli.run(%w(foo))
        end
      end

      context 'with --list-queues flag' do
        it 'errors when given --list-queues and --dryrun' do
          expect { cli.run(%w(foo --list-queues --dryrun)) }.to raise_error(described_class::CommandError)
        end

        it 'prints out a list of queues in alphabetical order' do
          expected_queues = [
            'epics:epics_update_epics_dates',
            'epics_new_epic_issue',
            'new_epic',
            'todos_destroyer:todos_destroyer_confidential_epic'
          ]

          allow(Gitlab::SidekiqConfig::CliMethods).to receive(:query_queues).and_return(expected_queues.shuffle)

          expect(cli).to receive(:puts).with([expected_queues])

          cli.run(%w(--queue-selector feature_category=epics --list-queues))
        end
      end

      context 'queue namespace expansion' do
        it 'starts Sidekiq workers for all queues in all_queues.yml with a namespace in argv' do
          expect(Gitlab::SidekiqConfig::CliMethods).to receive(:worker_queues).and_return(['cronjob:foo', 'cronjob:bar'])
          expect(Gitlab::SidekiqCluster).to receive(:start)
                                              .with([['cronjob', 'cronjob:foo', 'cronjob:bar']], default_options)
                                              .and_return([])

          cli.run(%w(cronjob))
        end
      end

      context "with --queue-selector" do
        where do
          {
            'memory-bound queues' => {
              query: 'resource_boundary=memory',
              included_queues: %w(project_export),
              excluded_queues: %w(merge)
            },
            'memory- or CPU-bound queues' => {
              query: 'resource_boundary=memory,cpu',
              included_queues: %w(auto_merge:auto_merge_process project_export),
              excluded_queues: %w(merge)
            },
            'high urgency CI queues' => {
              query: 'feature_category=continuous_integration&urgency=high',
              included_queues: %w(pipeline_cache:expire_job_cache pipeline_cache:expire_pipeline_cache),
              excluded_queues: %w(merge)
            },
            'CPU-bound high urgency CI queues' => {
              query: 'feature_category=continuous_integration&urgency=high&resource_boundary=cpu',
              included_queues: %w(pipeline_cache:expire_pipeline_cache),
              excluded_queues: %w(pipeline_cache:expire_job_cache merge)
            },
            'CPU-bound high urgency non-CI queues' => {
              query: 'feature_category!=continuous_integration&urgency=high&resource_boundary=cpu',
              included_queues: %w(new_issue),
              excluded_queues: %w(pipeline_cache:expire_pipeline_cache)
            },
            'CI and SCM queues' => {
              query: 'feature_category=continuous_integration|feature_category=source_code_management',
              included_queues: %w(pipeline_cache:expire_job_cache merge),
              excluded_queues: %w(mailers)
            }
          }
        end

        with_them do
          it 'expands queues by attributes' do
            expect(Gitlab::SidekiqCluster).to receive(:start) do |queues, opts|
              expect(opts).to eq(default_options)
              expect(queues.first).to include(*included_queues)
              expect(queues.first).not_to include(*excluded_queues)

              []
            end

            cli.run(%W(--queue-selector #{query}))
          end

          it 'works when negated' do
            expect(Gitlab::SidekiqCluster).to receive(:start) do |queues, opts|
              expect(opts).to eq(default_options)
              expect(queues.first).not_to include(*included_queues)
              expect(queues.first).to include(*excluded_queues)

              []
            end

            cli.run(%W(--negate --queue-selector #{query}))
          end
        end

        it 'expands multiple queue groups correctly' do
          expect(Gitlab::SidekiqCluster)
            .to receive(:start)
                  .with([['chat_notification'], ['project_export']], default_options)
                  .and_return([])

          cli.run(%w(--queue-selector feature_category=chatops&has_external_dependencies=true resource_boundary=memory&feature_category=importers))
        end

        it 'allows the special * selector' do
          worker_queues = %w(foo bar baz)

          expect(Gitlab::SidekiqConfig::CliMethods)
            .to receive(:worker_queues).and_return(worker_queues)

          expect(Gitlab::SidekiqCluster)
            .to receive(:start).with([worker_queues], default_options).and_return([])

          cli.run(%w(--queue-selector *))
        end

        it 'errors when the selector matches no queues' do
          expect(Gitlab::SidekiqCluster).not_to receive(:start)

          expect { cli.run(%w(--queue-selector has_external_dependencies=true&has_external_dependencies=false)) }
            .to raise_error(described_class::CommandError)
        end

        it 'errors on an invalid query multiple queue groups correctly' do
          expect(Gitlab::SidekiqCluster).not_to receive(:start)

          expect { cli.run(%w(--queue-selector unknown_field=chatops)) }
            .to raise_error(Gitlab::SidekiqConfig::WorkerMatcher::QueryError)
        end
      end
    end

    context 'metrics server' do
      let(:trapped_signals) { described_class::TERMINATE_SIGNALS + described_class::FORWARD_SIGNALS }
      let(:metrics_dir) { Dir.mktmpdir }

      before do
        stub_env('prometheus_multiproc_dir', metrics_dir)
      end

      after do
        FileUtils.rm_rf(metrics_dir, secure: true)
      end

      context 'starting the server' do
        context 'without --dryrun' do
          before do
            allow(Gitlab::SidekiqCluster).to receive(:start).and_return([])
          end

          it 'wipes the metrics directory before starting workers' do
            expect(metrics_cleanup_service).to receive(:execute).ordered
            expect(Gitlab::SidekiqCluster).to receive(:start).ordered.and_return([])

            cli.run(%w(foo))
          end

          context 'when there are no sidekiq_health_checks settings set' do
            let(:sidekiq_exporter_enabled) { true }

            it 'does not start a sidekiq metrics server' do
              expect(MetricsServer).not_to receive(:fork)

              cli.run(%w(foo))
            end
          end

          context 'when the sidekiq_exporter.port setting is not set' do
            let(:sidekiq_exporter_enabled) { true }

            it 'does not start a sidekiq metrics server' do
              expect(MetricsServer).not_to receive(:fork)

              cli.run(%w(foo))
            end
          end

          context 'when sidekiq_exporter.enabled setting is not set' do
            let(:config) do
              {
                'test' => {
                  'monitoring' => {
                    'sidekiq_exporter' => {},
                    'sidekiq_health_checks' => {
                      'address' => 'localhost',
                      'enabled' => sidekiq_exporter_enabled,
                      'port' => sidekiq_health_checks_port
                    }
                  }
                }
              }
            end

            it 'does not start a sidekiq metrics server' do
              expect(MetricsServer).not_to receive(:fork)

              cli.run(%w(foo))
            end
          end

          context 'with a blank sidekiq_exporter setting' do
            let(:config) do
              {
                'test' => {
                  'monitoring' => {
                    'sidekiq_exporter' => nil,
                    'sidekiq_health_checks' => nil
                  }
                }
              }
            end

            it 'does not start a sidekiq metrics server' do
              expect(MetricsServer).not_to receive(:fork)

              cli.run(%w(foo))
            end

            it 'does not throw an error' do
              expect { cli.run(%w(foo)) }.not_to raise_error
            end
          end

          context 'with valid settings' do
            using RSpec::Parameterized::TableSyntax

            where(:sidekiq_exporter_enabled, :sidekiq_exporter_port, :sidekiq_health_checks_port, :start_metrics_server) do
              true  | '3807' | '3907' | true
              true  | '3807' | '3807' | false
              false | '3807' | '3907' | false
              false | '3807' | '3907' | false
            end

            with_them do
              specify do
                if start_metrics_server
                  expect(MetricsServer).to receive(:fork).with('sidekiq', metrics_dir: metrics_dir, reset_signals: trapped_signals)
                else
                  expect(MetricsServer).not_to receive(:fork)
                end

                cli.run(%w(foo))
              end
            end
          end

          context 'when a PID is specified' do
            it 'writes the PID to a file' do
              expect(Gitlab::ProcessManagement).to receive(:write_pid).with('/dev/null')

              cli.option_parser.parse!(%w(-P /dev/null))
              cli.run(%w(foo))
            end
          end

          context 'when no PID is specified' do
            it 'does not write a PID' do
              expect(Gitlab::ProcessManagement).not_to receive(:write_pid)

              cli.run(%w(foo))
            end
          end
        end

        context 'with --dryrun set' do
          let(:sidekiq_exporter_enabled) { true }

          it 'does not start the server' do
            expect(MetricsServer).not_to receive(:fork)

            cli.run(%w(foo --dryrun))
          end
        end
      end
    end

    context 'supervising the cluster' do
      let(:sidekiq_exporter_enabled) { true }
      let(:sidekiq_health_checks_port) { '3907' }
      let(:metrics_server_pid) { 99 }
      let(:sidekiq_worker_pids) { [2, 42] }

      before do
        allow(Gitlab::SidekiqCluster).to receive(:start).and_return(sidekiq_worker_pids)
      end

      it 'stops the entire process cluster if one of the workers has been terminated' do
        expect(supervisor).to receive(:alive).and_return(true)
        expect(supervisor).to receive(:supervise).and_yield([2])
        expect(MetricsServer).to receive(:fork).once.and_return(metrics_server_pid)
        expect(Gitlab::ProcessManagement).to receive(:signal_processes).with([42, 99], :TERM)

        cli.run(%w(foo))
      end

      context 'when the supervisor is alive' do
        it 'restarts the metrics server when it is down' do
          expect(supervisor).to receive(:alive).and_return(true)
          expect(supervisor).to receive(:supervise).and_yield([metrics_server_pid])
          expect(MetricsServer).to receive(:fork).twice.and_return(metrics_server_pid)

          cli.run(%w(foo))
        end
      end

      context 'when the supervisor is shutting down' do
        it 'does not restart the metrics server' do
          expect(supervisor).to receive(:alive).and_return(false)
          expect(supervisor).to receive(:supervise).and_yield([metrics_server_pid])
          expect(MetricsServer).to receive(:fork).once.and_return(metrics_server_pid)

          cli.run(%w(foo))
        end
      end
    end
  end
end
