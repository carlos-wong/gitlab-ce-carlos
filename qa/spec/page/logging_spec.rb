# frozen_string_literal: true

require 'capybara/dsl'

describe QA::Support::Page::Logging do
  include Support::StubENV

  let(:page) { double().as_null_object }

  before do
    logger = Logger.new $stdout
    logger.level = ::Logger::DEBUG
    QA::Runtime::Logger.logger = logger

    allow(Capybara).to receive(:current_session).and_return(page)
    allow(page).to receive(:current_url).and_return('http://current-url')
    allow(page).to receive(:has_css?).with(any_args).and_return(true)
  end

  subject do
    Class.new(QA::Page::Base) do
      prepend QA::Support::Page::Logging
    end.new
  end

  it 'logs refresh' do
    expect { subject.refresh }
      .to output(%r{refreshing http://current-url}).to_stdout_from_any_process
  end

  it 'logs wait' do
    expect { subject.wait(max: 0) {} }
      .to output(/with wait/).to_stdout_from_any_process
    expect { subject.wait(max: 0) {} }
      .to output(/ended wait after .* seconds$/).to_stdout_from_any_process
  end

  it 'logs scroll_to' do
    expect { subject.scroll_to(:element) }
      .to output(/scrolling to :element/).to_stdout_from_any_process
  end

  it 'logs asset_exists?' do
    expect { subject.asset_exists?('http://asset-url') }
      .to output(%r{asset_exists\? http://asset-url returned false}).to_stdout_from_any_process
  end

  it 'logs find_element' do
    expect { subject.find_element(:element) }
      .to output(/finding :element/).to_stdout_from_any_process
    expect { subject.find_element(:element) }
      .to output(/found :element/).to_stdout_from_any_process
  end

  it 'logs find_element with text_filter' do
    expect { subject.find_element(:element, 'foo') }
      .to output(/finding :element with text_filter "foo"/).to_stdout_from_any_process
    expect { subject.find_element(:element, 'foo') }
      .to output(/found :element/).to_stdout_from_any_process
  end

  it 'logs click_element' do
    expect { subject.click_element(:element) }
      .to output(/clicking :element/).to_stdout_from_any_process
  end

  it 'logs fill_element' do
    expect { subject.fill_element(:element, 'foo') }
      .to output(/filling :element with "foo"/).to_stdout_from_any_process
  end

  it 'logs has_element?' do
    expect { subject.has_element?(:element) }
      .to output(/has_element\? :element returned true/).to_stdout_from_any_process
  end

  it 'logs has_no_text?' do
    allow(page).to receive(:has_no_text?).with('foo').and_return(true)

    expect { subject.has_no_text? 'foo' }
      .to output(/has_no_text\?\('foo'\) returned true/).to_stdout_from_any_process
  end

  it 'logs within_element' do
    expect { subject.within_element(:element) }
      .to output(/within element :element/).to_stdout_from_any_process
    expect { subject.within_element(:element) }
      .to output(/end within element :element/).to_stdout_from_any_process
  end

  context 'all_elements' do
    it 'logs the number of elements found' do
      allow(page).to receive(:all).and_return([1, 2])

      expect { subject.all_elements(:element) }
        .to output(/finding all :element/).to_stdout_from_any_process
      expect { subject.all_elements(:element) }
        .to output(/found 2 :element/).to_stdout_from_any_process
    end

    it 'logs 0 if no elements are found' do
      allow(page).to receive(:all).and_return([])

      expect { subject.all_elements(:element) }
        .to output(/finding all :element/).to_stdout_from_any_process
      expect { subject.all_elements(:element) }
        .not_to output(/found 0 :elements/).to_stdout_from_any_process
    end
  end
end
