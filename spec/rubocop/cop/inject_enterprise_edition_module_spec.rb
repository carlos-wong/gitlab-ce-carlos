# frozen_string_literal: true

require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../rubocop/cop/inject_enterprise_edition_module'

describe RuboCop::Cop::InjectEnterpriseEditionModule do
  include CopHelper

  subject(:cop) { described_class.new }

  it 'flags the use of `prepend EE` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      prepend EE::Foo
      ^^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'does not flag the use of `prepend EEFoo` in the middle of a file' do
    expect_no_offenses(<<~SOURCE)
    class Foo
      prepend EEFoo
    end
    SOURCE
  end

  it 'flags the use of `prepend EE::Foo::Bar` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      prepend EE::Foo::Bar
      ^^^^^^^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'flags the use of `prepend(EE::Foo::Bar)` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      prepend(EE::Foo::Bar)
      ^^^^^^^^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'flags the use of `prepend EE::Foo::Bar::Baz` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      prepend EE::Foo::Bar::Baz
      ^^^^^^^^^^^^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'flags the use of `prepend ::EE` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      prepend ::EE::Foo
      ^^^^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'flags the use of `include EE` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      include EE::Foo
      ^^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'flags the use of `include ::EE` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      include ::EE::Foo
      ^^^^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'flags the use of `extend EE` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      extend EE::Foo
      ^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'flags the use of `extend ::EE` in the middle of a file' do
    expect_offense(<<~SOURCE)
    class Foo
      extend ::EE::Foo
      ^^^^^^^^^^^^^^^^ Injecting EE modules must be done on the last line of this file, outside of any class or module definitions
    end
    SOURCE
  end

  it 'does not flag prepending of regular modules' do
    expect_no_offenses(<<~SOURCE)
    class Foo
      prepend Foo
    end
    SOURCE
  end

  it 'does not flag including of regular modules' do
    expect_no_offenses(<<~SOURCE)
    class Foo
      include Foo
    end
    SOURCE
  end

  it 'does not flag extending using regular modules' do
    expect_no_offenses(<<~SOURCE)
    class Foo
      extend Foo
    end
    SOURCE
  end

  it 'does not flag the use of `prepend EE` on the last line' do
    expect_no_offenses(<<~SOURCE)
    class Foo
    end

    Foo.prepend(EE::Foo)
    SOURCE
  end

  it 'does not flag the use of `include EE` on the last line' do
    expect_no_offenses(<<~SOURCE)
    class Foo
    end

    Foo.include(EE::Foo)
    SOURCE
  end

  it 'does not flag the use of `extend EE` on the last line' do
    expect_no_offenses(<<~SOURCE)
    class Foo
    end

    Foo.extend(EE::Foo)
    SOURCE
  end

  it 'autocorrects offenses by just disabling the Cop' do
    source = <<~SOURCE
    class Foo
      prepend EE::Foo
      include Bar
    end
    SOURCE

    expect(autocorrect_source(source)).to eq(<<~SOURCE)
    class Foo
      prepend EE::Foo # rubocop: disable Cop/InjectEnterpriseEditionModule
      include Bar
    end
    SOURCE
  end
end
