# frozen_string_literal: true

require "ostruct"
require "bundle"
require "bundle/skipper"
require "bundle/dsl"

RSpec.describe Homebrew::Bundle::Skipper do
  subject(:skipper) { described_class }

  before do
    allow(ENV).to receive(:[]).and_return(nil)
    allow(ENV).to receive(:[]).with("HOMEBREW_BUNDLE_BREW_SKIP").and_return("mysql")
    allow(ENV).to receive(:[]).with("HOMEBREW_BUNDLE_WHALEBREW_SKIP").and_return("whalebrew/imagemagick")
    allow(ENV).to receive(:[]).with("HOMEBREW_BUNDLE_TAP_SKIP").and_return("org/repo")
    allow(Formatter).to receive(:warning)
    skipper.instance_variable_set(:@skipped_entries, nil)
    skipper.instance_variable_set(:@failed_taps, nil)
  end

  describe ".skip?" do
    context "with a listed formula" do
      let(:entry) { Homebrew::Bundle::Dsl::Entry.new(:brew, "mysql") }

      it "returns true" do
        expect(skipper.skip?(entry)).to be true
      end
    end

    context "with an unbottled formula on ARM", :needs_macos do
      let(:entry) { Homebrew::Bundle::Dsl::Entry.new(:brew, "mysql") }

      # TODO: remove OpenStruct usage
      # rubocop:todo Style/OpenStructUse
      it "returns true" do
        allow(Hardware::CPU).to receive(:arm?).and_return(true)
        allow_any_instance_of(Formula).to receive(:stable).and_return(OpenStruct.new(bottled?:        false,
                                                                                     bottle_defined?: true))

        expect(skipper.skip?(entry)).to be true
      end
      # rubocop:enable Style/OpenStructUse
    end

    context "with an unlisted cask", :needs_macos do
      let(:entry) { Homebrew::Bundle::Dsl::Entry.new(:cask, "java") }

      it "returns false" do
        expect(skipper.skip?(entry)).to be false
      end
    end

    context "with a listed whalebrew image" do
      let(:entry) { Homebrew::Bundle::Dsl::Entry.new(:whalebrew, "whalebrew/imagemagick") }

      it "returns true" do
        expect(skipper.skip?(entry)).to be true
      end
    end

    context "with a listed formula in a failed tap" do
      let(:entry) { Homebrew::Bundle::Dsl::Entry.new(:brew, "org/repo/formula") }

      it "returns true" do
        skipper.tap_failed!("org/repo")

        expect(skipper.skip?(entry)).to be true
      end
    end
  end

  describe ".failed_tap!" do
    context "with a tap" do
      let(:tap) { Homebrew::Bundle::Dsl::Entry.new(:tap, "org/repo-b") }
      let(:entry) { Homebrew::Bundle::Dsl::Entry.new(:brew, "org/repo-b/formula") }

      it "returns false" do
        expect(skipper.skip?(entry)).to be false

        skipper.tap_failed! tap.name

        expect(skipper.skip?(entry)).to be true
      end
    end
  end
end
