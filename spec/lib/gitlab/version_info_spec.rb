# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::VersionInfo do
  before do
    @unknown = described_class.new
    @v0_0_1 = described_class.new(0, 0, 1)
    @v0_1_0 = described_class.new(0, 1, 0)
    @v1_0_0 = described_class.new(1, 0, 0)
    @v1_0_1 = described_class.new(1, 0, 1)
    @v1_0_1_b1 = described_class.new(1, 0, 1, '-b1')
    @v1_0_1_rc1 = described_class.new(1, 0, 1, '-rc1')
    @v1_0_1_rc2 = described_class.new(1, 0, 1, '-rc2')
    @v1_1_0 = described_class.new(1, 1, 0)
    @v1_1_0_beta1 = described_class.new(1, 1, 0, '-beta1')
    @v2_0_0 = described_class.new(2, 0, 0)
    @v13_10_1_1574_89 = described_class.parse("v13.10.1~beta.1574.gf6ea9389", parse_suffix: true)
    @v13_10_1_1575_89 = described_class.parse("v13.10.1~beta.1575.gf6ea9389", parse_suffix: true)
    @v13_10_1_1575_90 = described_class.parse("v13.10.1~beta.1575.gf6ea9390", parse_suffix: true)
  end

  describe '>' do
    it { expect(@v2_0_0).to be > @v1_1_0 }
    it { expect(@v1_1_0).to be > @v1_0_1 }
    it { expect(@v1_0_1_b1).to be > @v1_0_0 }
    it { expect(@v1_0_1_rc1).to be > @v1_0_0 }
    it { expect(@v1_0_1_rc1).to be > @v1_0_1_b1 }
    it { expect(@v1_0_1_rc2).to be > @v1_0_1_rc1 }
    it { expect(@v1_0_1).to be > @v1_0_1_rc1 }
    it { expect(@v1_0_1).to be > @v1_0_1_rc2 }
    it { expect(@v1_0_1).to be > @v1_0_0 }
    it { expect(@v1_0_0).to be > @v0_1_0 }
    it { expect(@v1_1_0_beta1).to be > @v1_0_1_rc2 }
    it { expect(@v1_1_0).to be > @v1_1_0_beta1 }
    it { expect(@v0_1_0).to be > @v0_0_1 }
  end

  describe '>=' do
    it { expect(@v2_0_0).to be >= described_class.new(2, 0, 0) }
    it { expect(@v2_0_0).to be >= @v1_1_0 }
    it { expect(@v1_0_1_rc2).to be >= @v1_0_1_rc1 }
  end

  describe '<' do
    it { expect(@v0_0_1).to be < @v0_1_0 }
    it { expect(@v0_1_0).to be < @v1_0_0 }
    it { expect(@v1_0_0).to be < @v1_0_1 }
    it { expect(@v1_0_1).to be < @v1_1_0 }
    it { expect(@v1_0_0).to be < @v1_0_1_rc2 }
    it { expect(@v1_0_1_rc1).to be < @v1_0_1 }
    it { expect(@v1_0_1_rc1).to be < @v1_0_1_rc2 }
    it { expect(@v1_0_1_rc2).to be < @v1_0_1 }
    it { expect(@v1_1_0).to be < @v2_0_0 }
    it { expect(@v13_10_1_1574_89).to be < @v13_10_1_1575_89 }
    it { expect(@v13_10_1_1575_89).to be < @v13_10_1_1575_90 }
  end

  describe '<=' do
    it { expect(@v0_0_1).to be <= described_class.new(0, 0, 1) }
    it { expect(@v0_0_1).to be <= @v0_1_0 }
    it { expect(@v1_0_1_b1).to be <= @v1_0_1_rc1 }
    it { expect(@v1_0_1_rc1).to be <= @v1_0_1_rc2 }
    it { expect(@v1_1_0_beta1).to be <= @v1_1_0 }
  end

  describe '==' do
    it { expect(@v0_0_1).to eq(described_class.new(0, 0, 1)) }
    it { expect(@v0_1_0).to eq(described_class.new(0, 1, 0)) }
    it { expect(@v1_0_0).to eq(described_class.new(1, 0, 0)) }
    it { expect(@v1_0_1_rc1).to eq(described_class.new(1, 0, 1, '-rc1')) }
  end

  describe '!=' do
    it { expect(@v0_0_1).not_to eq(@v0_1_0) }
    it { expect(@v1_0_1_rc1).not_to eq(@v1_0_1_rc2) }
  end

  describe '.unknown' do
    it { expect(@unknown).not_to be @v0_0_1 }
    it { expect(@unknown).not_to be described_class.new }
    it { expect {@unknown > @v0_0_1}.to raise_error(ArgumentError) }
    it { expect {@unknown < @v0_0_1}.to raise_error(ArgumentError) }
  end

  describe '.parse' do
    it { expect(described_class.parse("1.0.0")).to eq(@v1_0_0) }
    it { expect(described_class.parse("1.0.0.1")).to eq(@v1_0_0) }
    it { expect(described_class.parse("1.0.0-ee")).to eq(@v1_0_0) }
    it { expect(described_class.parse("1.0.0-rc1")).to eq(@v1_0_0) }
    it { expect(described_class.parse("1.0.0-rc1-ee")).to eq(@v1_0_0) }
    it { expect(described_class.parse("git 1.0.0b1")).to eq(@v1_0_0) }
    it { expect(described_class.parse("git 1.0b1")).not_to be_valid }

    context 'with parse_suffix: true' do
      let(:versions) do
        <<-VERSIONS.lines
        0.0.1
        0.1.0
        1.0.0
        1.0.1-b1
        1.0.1-rc1
        1.0.1-rc2
        1.0.1
        1.1.0-beta1
        1.1.0
        2.0.0
        v13.10.0-pre
        v13.10.0-rc1
        v13.10.0-rc2
        v13.10.0
        v13.10.1~beta.1574.gf6ea9389
        v13.10.1~beta.1575.gf6ea9389
        v13.10.1-rc1
        v13.10.1-rc2
        v13.10.1
        VERSIONS
      end

      let(:parsed_versions) do
        versions.map(&:strip).map { |version| described_class.parse(version, parse_suffix: true) }
      end

      it 'versions are returned in a correct order' do
        expect(parsed_versions.shuffle.sort).to eq(parsed_versions)
      end
    end
  end

  describe '.to_s' do
    it { expect(@v1_0_0.to_s).to eq("1.0.0") }
    it { expect(@v1_0_1_rc1.to_s).to eq("1.0.1-rc1") }
    it { expect(@unknown.to_s).to eq("Unknown") }
  end

  describe '.hash' do
    it { expect(described_class.parse("1.0.0").hash).to eq(@v1_0_0.hash) }
    it { expect(described_class.parse("1.0.0.1").hash).to eq(@v1_0_0.hash) }
    it { expect(described_class.parse("1.0.1b1").hash).to eq(@v1_0_1.hash) }
    it { expect(described_class.parse("1.0.1-rc1", parse_suffix: true).hash).to eq(@v1_0_1_rc1.hash) }
  end

  describe '.eql?' do
    it { expect(described_class.parse("1.0.0").eql?(@v1_0_0)).to be_truthy }
    it { expect(described_class.parse("1.0.0.1").eql?(@v1_0_0)).to be_truthy }
    it { expect(@v1_0_1_rc1.eql?(@v1_0_1_rc1)).to be_truthy }
    it { expect(@v1_0_1_rc1.eql?(@v1_0_1_rc2)).to be_falsey }
    it { expect(@v1_0_1_rc1.eql?(@v1_0_1)).to be_falsey }
    it { expect(@v1_0_1.eql?(@v1_0_0)).to be_falsey }
    it { expect(@v1_1_0.eql?(@v1_0_0)).to be_falsey }
    it { expect(@v1_0_0.eql?(@v1_0_0)).to be_truthy }
    it { expect([@v1_0_0, @v1_1_0, @v1_0_0, @v1_0_1_rc1, @v1_0_1_rc1].uniq).to eq [@v1_0_0, @v1_1_0, @v1_0_1_rc1] }
  end

  describe '.same_minor_version?' do
    it { expect(@v0_1_0.same_minor_version?(@v0_0_1)).to be_falsey }
    it { expect(@v1_0_1.same_minor_version?(@v1_0_0)).to be_truthy }
    it { expect(@v1_0_1_rc1.same_minor_version?(@v1_0_0)).to be_truthy }
    it { expect(@v1_0_0.same_minor_version?(@v1_0_1)).to be_truthy }
    it { expect(@v1_1_0.same_minor_version?(@v1_0_0)).to be_falsey }
    it { expect(@v2_0_0.same_minor_version?(@v1_0_0)).to be_falsey }
  end

  describe '.without_patch' do
    it { expect(@v0_1_0.without_patch).to eq(@v0_1_0) }
    it { expect(@v1_0_0.without_patch).to eq(@v1_0_0) }
    it { expect(@v1_0_1.without_patch).to eq(@v1_0_0) }
    it { expect(@v1_0_1_rc1.without_patch).to eq(@v1_0_0) }
  end
end
