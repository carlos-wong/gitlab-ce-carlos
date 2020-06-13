# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Template::Finders::GlobalTemplateFinder do
  let(:base_dir) { Dir.mktmpdir }

  def create_template!(name_with_category)
    full_path = File.join(base_dir, name_with_category)
    FileUtils.mkdir_p(File.dirname(full_path))
    FileUtils.touch(full_path)
  end

  after do
    FileUtils.rm_rf(base_dir)
  end

  subject(:finder) { described_class.new(base_dir, '', { 'General' => '', 'Bar' => 'Bar' }, exclusions: exclusions) }

  let(:exclusions) { [] }

  describe '.find' do
    context 'with a non-prefixed General template' do
      before do
        create_template!('test-template')
      end

      it 'finds the template with no prefix' do
        expect(finder.find('test-template')).to be_present
      end

      it 'does not find a prefixed template' do
        expect(finder.find('Bar/test-template')).to be_nil
      end

      it 'does not permit path traversal requests' do
        expect { finder.find('../foo') }.to raise_error(/Invalid path/)
      end

      context 'while listed as an exclusion' do
        let(:exclusions) { %w[test-template] }

        it 'does not find the template without a prefix' do
          expect(finder.find('test-template')).to be_nil
        end

        it 'does not find the template with a prefix' do
          expect(finder.find('Bar/test-template')).to be_nil
        end

        it 'finds another prefixed template with the same name' do
          create_template!('Bar/test-template')

          expect(finder.find('test-template')).to be_nil
          expect(finder.find('Bar/test-template')).to be_present
        end
      end
    end

    context 'with a prefixed template' do
      before do
        create_template!('Bar/test-template')
      end

      it 'finds the template with a prefix' do
        expect(finder.find('Bar/test-template')).to be_present
      end

      # NOTE: This spec fails, the template Bar/test-template is found
      # See Gitlab issue: https://gitlab.com/gitlab-org/gitlab/issues/205719
      xit 'does not find the template without a prefix' do
        expect(finder.find('test-template')).to be_nil
      end

      it 'does not permit path traversal requests' do
        expect { finder.find('../foo') }.to raise_error(/Invalid path/)
      end

      context 'while listed as an exclusion' do
        let(:exclusions) { %w[Bar/test-template] }

        it 'does not find the template with a prefix' do
          expect(finder.find('Bar/test-template')).to be_nil
        end

        # NOTE: This spec fails, the template Bar/test-template is found
        # See Gitlab issue: https://gitlab.com/gitlab-org/gitlab/issues/205719
        xit 'does not find the template without a prefix' do
          expect(finder.find('test-template')).to be_nil
        end

        it 'finds another non-prefixed template with the same name' do
          create_template!('Bar/test-template')

          expect(finder.find('test-template')).to be_present
          expect(finder.find('Bar/test-template')).to be_nil
        end
      end
    end
  end
end
