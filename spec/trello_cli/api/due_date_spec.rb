# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::DueDate do
  # A fixed zone keeps the expected UTC strings literal. September is EDT,
  # so local noon is 16:00Z.
  around do |example|
    saved = ENV["TZ"]
    ENV["TZ"] = "America/New_York"
    example.run
  ensure
    ENV["TZ"] = saved
  end

  let(:now) { Time.new(2026, 9, 9, 8, 30, 0) }

  describe "clearing" do
    it "returns nil for none" do
      expect(described_class.parse("none", now: now)).to be_nil
    end

    it "ignores case on none" do
      expect(described_class.parse("NONE", now: now)).to be_nil
    end
  end

  describe "ISO dates" do
    it "puts a bare date at noon local time" do
      expect(described_class.parse("2026-09-15", now: now)).to eq("2026-09-15T16:00:00Z")
    end

    it "keeps the time given on a date-time" do
      expect(described_class.parse("2026-09-15T17:00", now: now)).to eq("2026-09-15T21:00:00Z")
    end

    it "accepts seconds" do
      expect(described_class.parse("2026-09-15T17:00:30", now: now)).to eq("2026-09-15T21:00:30Z")
    end

    it "honors an explicit UTC marker" do
      expect(described_class.parse("2026-09-15T17:00Z", now: now)).to eq("2026-09-15T17:00:00Z")
    end

    it "honors an explicit offset" do
      expect(described_class.parse("2026-09-15T17:00-07:00", now: now)).to eq("2026-09-16T00:00:00Z")
    end

    it "rejects an impossible date" do
      expect { described_class.parse("2026-02-30", now: now) }
        .to raise_error(TrelloCli::Error, /Invalid due date: 2026-02-30/)
    end
  end

  describe "keywords" do
    it "puts today at noon local time" do
      expect(described_class.parse("today", now: now)).to eq("2026-09-09T16:00:00Z")
    end

    it "puts tomorrow at noon local time" do
      expect(described_class.parse("tomorrow", now: now)).to eq("2026-09-10T16:00:00Z")
    end

    it "ignores case on keywords" do
      expect(described_class.parse("Tomorrow", now: now)).to eq("2026-09-10T16:00:00Z")
    end
  end

  describe "relative offsets" do
    it "advances whole days" do
      expect(described_class.parse("+3d", now: now)).to eq("2026-09-12T16:00:00Z")
    end

    it "advances whole weeks" do
      expect(described_class.parse("+2w", now: now)).to eq("2026-09-23T16:00:00Z")
    end

    it "treats +0d as today" do
      expect(described_class.parse("+0d", now: now)).to eq("2026-09-09T16:00:00Z")
    end

    it "crosses a month boundary" do
      expect(described_class.parse("+30d", now: now)).to eq("2026-10-09T16:00:00Z")
    end
  end

  describe "rejections" do
    it "rejects free text" do
      expect { described_class.parse("next friday", now: now) }
        .to raise_error(TrelloCli::Error, /Invalid due date: next friday/)
    end

    it "rejects a bare number" do
      expect { described_class.parse("15", now: now) }
        .to raise_error(TrelloCli::Error, /Invalid due date: 15/)
    end

    it "rejects an unknown offset unit" do
      expect { described_class.parse("+3y", now: now) }
        .to raise_error(TrelloCli::Error, /Invalid due date: \+3y/)
    end

    it "rejects a negative offset" do
      expect { described_class.parse("-1d", now: now) }
        .to raise_error(TrelloCli::Error, /Invalid due date: -1d/)
    end

    it "names the accepted forms" do
      expect { described_class.parse("whenever", now: now) }
        .to raise_error(TrelloCli::Error, /YYYY-MM-DD.*today.*tomorrow.*none/m)
    end
  end

  it "defaults now to the current time" do
    expect(described_class.parse("today")).to eq("#{Time.now.strftime('%Y-%m-%d')}T16:00:00Z")
  end
end
