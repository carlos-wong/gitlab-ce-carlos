require 'spec_helper'

describe Gitlab::Profiler do
  let(:null_logger) { Logger.new('/dev/null') }
  let(:private_token) { 'private' }

  describe '.profile' do
    let(:app) { double(:app) }

    before do
      allow(ActionDispatch::Integration::Session).to receive(:new).and_return(app)
      allow(app).to receive(:get)
    end

    it 'returns a profile result' do
      expect(described_class.profile('/')).to be_an_instance_of(RubyProf::Profile)
    end

    it 'uses the custom logger given' do
      expect(described_class).to receive(:create_custom_logger)
                                   .with(null_logger, private_token: anything)
                                   .and_call_original

      described_class.profile('/', logger: null_logger)
    end

    it 'sends a POST request when data is passed' do
      post_data = '{"a":1}'

      expect(app).to receive(:post).with(anything, post_data, anything)

      described_class.profile('/', post_data: post_data)
    end

    it 'uses the private_token for auth if given' do
      expect(app).to receive(:get).with('/', nil, 'Private-Token' => private_token)
      expect(app).to receive(:get).with('/api/v4/users')

      described_class.profile('/', private_token: private_token)
    end

    it 'uses the user for auth if given' do
      user = double(:user)

      expect(described_class).to receive(:with_user).with(user)

      described_class.profile('/', user: user)
    end

    it 'uses the private_token for auth if both it and user are set' do
      user = double(:user)

      expect(described_class).to receive(:with_user).with(nil).and_call_original
      expect(app).to receive(:get).with('/', nil, 'Private-Token' => private_token)
      expect(app).to receive(:get).with('/api/v4/users')

      described_class.profile('/', user: user, private_token: private_token)
    end
  end

  describe '.create_custom_logger' do
    it 'does nothing when nil is passed' do
      expect(described_class.create_custom_logger(nil)).to be_nil
    end

    context 'the new logger' do
      let(:custom_logger) do
        described_class.create_custom_logger(null_logger, private_token: private_token)
      end

      it 'does not affect the existing logger' do
        expect(null_logger).not_to receive(:debug)
        expect(custom_logger).to receive(:debug).and_call_original

        custom_logger.debug('Foo')
      end

      it 'strips out the private token' do
        expect(custom_logger).to receive(:add) do |severity, _progname, message|
          next if message.include?('spec/')

          expect(severity).to eq(Logger::DEBUG)
          expect(message).to include('public').and include(described_class::FILTERED_STRING)
          expect(message).not_to include(private_token)
        end.twice

        custom_logger.debug("public #{private_token}")
      end

      it 'tracks model load times by model' do
        custom_logger.debug('This is not a model load')
        custom_logger.debug('User Load (1.2ms)')
        custom_logger.debug('User Load (1.3ms)')
        custom_logger.debug('Project Load (10.4ms)')

        expect(custom_logger.load_times_by_model).to eq('User' => [1.2, 1.3],
                                                        'Project' => [10.4])
      end

      it 'logs the backtrace, ignoring lines as appropriate' do
        # Skip Rails's backtrace cleaning.
        allow(Rails.backtrace_cleaner).to receive(:clean, &:itself)

        expect(custom_logger).to receive(:add)
                                   .with(Logger::DEBUG,
                                         anything,
                                         a_string_matching(File.basename(__FILE__)))
                                   .twice

        expect(custom_logger).not_to receive(:add).with(Logger::DEBUG,
                                                        anything,
                                                        a_string_matching('lib/gitlab/profiler.rb'))

        # Force a part of the backtrace to be in the (ignored) profiler source
        # file.
        described_class.with_custom_logger(nil) { custom_logger.debug('Foo') }
      end
    end
  end

  describe '.clean_backtrace' do
    it 'uses the Rails backtrace cleaner' do
      backtrace = []

      expect(Rails.backtrace_cleaner).to receive(:clean).with(backtrace)

      described_class.clean_backtrace(backtrace)
    end

    it 'removes lines from IGNORE_BACKTRACES' do
      backtrace = [
        "lib/gitlab/gitaly_client.rb:294:in `block (2 levels) in migrate'",
        "lib/gitlab/gitaly_client.rb:331:in `allow_n_plus_1_calls'",
        "lib/gitlab/gitaly_client.rb:280:in `block in migrate'",
        "lib/gitlab/metrics/influx_db.rb:103:in `measure'",
        "lib/gitlab/gitaly_client.rb:278:in `migrate'",
        "lib/gitlab/git/repository.rb:1451:in `gitaly_migrate'",
        "lib/gitlab/git/commit.rb:66:in `find'",
        "app/models/repository.rb:1047:in `find_commit'",
        "lib/gitlab/metrics/instrumentation.rb:159:in `block in find_commit'",
        "lib/gitlab/metrics/method_call.rb:36:in `measure'",
        "lib/gitlab/metrics/instrumentation.rb:159:in `find_commit'",
        "app/models/repository.rb:113:in `commit'",
        "lib/gitlab/i18n.rb:50:in `with_locale'",
        "lib/gitlab/middleware/multipart.rb:95:in `call'",
        "lib/gitlab/request_profiler/middleware.rb:14:in `call'",
        "ee/lib/gitlab/database/load_balancing/rack_middleware.rb:37:in `call'",
        "ee/lib/gitlab/jira/middleware.rb:15:in `call'"
      ]

      expect(described_class.clean_backtrace(backtrace))
        .to eq([
                 "lib/gitlab/gitaly_client.rb:294:in `block (2 levels) in migrate'",
                 "lib/gitlab/gitaly_client.rb:331:in `allow_n_plus_1_calls'",
                 "lib/gitlab/gitaly_client.rb:280:in `block in migrate'",
                 "lib/gitlab/gitaly_client.rb:278:in `migrate'",
                 "lib/gitlab/git/repository.rb:1451:in `gitaly_migrate'",
                 "lib/gitlab/git/commit.rb:66:in `find'",
                 "app/models/repository.rb:1047:in `find_commit'",
                 "app/models/repository.rb:113:in `commit'",
                 "ee/lib/gitlab/jira/middleware.rb:15:in `call'"
               ])
    end
  end

  describe '.with_custom_logger' do
    context 'when the logger is set' do
      it 'uses the replacement logger for the duration of the block' do
        expect(null_logger).to receive(:debug).and_call_original

        expect { described_class.with_custom_logger(null_logger) { ActiveRecord::Base.logger.debug('foo') } }
          .to not_change { ActiveRecord::Base.logger }
          .and not_change { ActionController::Base.logger }
          .and not_change { ActiveSupport::LogSubscriber.colorize_logging }
      end

      it 'returns the result of the block' do
        expect(described_class.with_custom_logger(null_logger) { 2 }).to eq(2)
      end
    end

    context 'when the logger is nil' do
      it 'returns the result of the block' do
        expect(described_class.with_custom_logger(nil) { 2 }).to eq(2)
      end

      it 'does not modify the standard Rails loggers' do
        expect { described_class.with_custom_logger(nil) {} }
          .to not_change { ActiveRecord::Base.logger }
          .and not_change { ActionController::Base.logger }
          .and not_change { ActiveSupport::LogSubscriber.colorize_logging }
      end
    end
  end

  describe '.with_user' do
    context 'when the user is set' do
      let(:user) { double(:user) }

      it 'overrides auth in ApplicationController to use the given user' do
        expect(described_class.with_user(user) { ApplicationController.new.current_user }).to eq(user)
      end

      it 'cleans up ApplicationController afterwards' do
        expect { described_class.with_user(user) {} }
          .to not_change { ActionController.instance_methods(false) }
      end
    end

    context 'when the user is nil' do
      it 'does not define methods on ApplicationController' do
        expect(ApplicationController).not_to receive(:define_method)

        described_class.with_user(nil) {}
      end
    end
  end

  describe '.log_load_times_by_model' do
    it 'logs the model, query count, and time by slowest first' do
      expect(null_logger).to receive(:load_times_by_model).and_return(
        'User' => [1.2, 1.3],
        'Project' => [10.4]
      )

      expect(null_logger).to receive(:info).with('Project total (1): 10.4ms')
      expect(null_logger).to receive(:info).with('User total (2): 2.5ms')

      described_class.log_load_times_by_model(null_logger)
    end

    it 'does nothing when called with a logger that does not have load times' do
      expect(null_logger).not_to receive(:info)

      expect(described_class.log_load_times_by_model(null_logger)).to be_nil
    end
  end
end
