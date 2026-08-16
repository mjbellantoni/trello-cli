# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::KindValidator do
  def valid_bug(overrides = {})
    { steps: ["Open Reports"], expected: "CSV downloads.", actual: "Spinner hangs." }.merge(overrides)
  end

  def call_bug(values: valid_bug, title: "Export times out", cap: 200)
    described_class.call(kind: :bug, title: title, values: values, cap: cap)
  end

  describe "a valid card" do
    it "is ok" do
      expect(call_bug).to be_ok
    end

    it "reports no errors" do
      expect(call_bug.errors).to be_empty
    end

    it "exposes the assembled description" do
      expect(call_bug.description).to include("## Steps to Recreate")
    end

    it "exposes a per-field breakdown summing to the total" do
      result = call_bug
      expect(result.breakdown.sum { |(_flag, count)| count }).to eq(result.word_count)
    end
  end

  describe "required fields" do
    it "rejects a nil required field" do
      expect(call_bug(values: valid_bug(actual: nil))).not_to be_ok
    end

    it "rejects a whitespace-only required field" do
      result = call_bug(values: valid_bug(actual: "   "))
      expect(result.errors.first).to include("--actual")
    end

    it "rejects an array field whose entries are all blank" do
      expect(call_bug(values: valid_bug(steps: ["", "  "]))).not_to be_ok
    end

    it "does not require notes" do
      expect(call_bug(values: valid_bug(notes: nil))).to be_ok
    end

    it "reports every missing field at once" do
      result = call_bug(values: valid_bug(actual: nil, expected: nil))
      expect(result.errors.first).to include("--expected").and include("--actual")
    end
  end

  describe "title prefix" do
    it "rejects a bug-prefixed title" do
      result = call_bug(title: "Bug: export times out")
      expect(result.errors.join).to include("the label carries the kind")
    end

    it "rejects the prefix regardless of case or spacing" do
      expect(call_bug(title: "BUG : export times out")).not_to be_ok
    end

    it "allows a title that merely contains a colon" do
      expect(call_bug(title: "Export: the 90-day range times out")).to be_ok
    end
  end

  describe "gherkin" do
    def call_feature(done_when)
      described_class.call(kind: :feature, title: "Filter the queue",
                           values: { what: "Filter", why: "Speed", done_when: done_when }, cap: 150)
    end

    it "accepts Given/When/Then" do
      expect(call_feature(["Given a queue", "When I filter", "Then it narrows"])).to be_ok
    end

    it "rejects done-when with no gherkin" do
      result = call_feature(["The filter works"])
      expect(result.errors.join).to include("Given, When, and Then")
    end

    it "rejects done-when missing only Then" do
      expect(call_feature(["Given a queue", "When I filter"])).not_to be_ok
    end

    it "does not require gherkin for a chore" do
      result = described_class.call(kind: :chore, title: "Drop table",
                                    values: { what: "Drop it", why_now: "Blocks work",
                                              done_when: ["Table is gone"] }, cap: 150)
      expect(result).to be_ok
    end
  end

  describe "the word cap" do
    it "accepts a description exactly at the cap" do
      result = call_bug(cap: call_bug.word_count)
      expect(result).to be_ok
    end

    it "rejects a description one word over the cap" do
      expect(call_bug(cap: call_bug.word_count - 1)).not_to be_ok
    end

    it "names both structural remedies rather than a word delta" do
      message = call_bug(cap: 1).errors.join
      expect(message).to include("split it")
      expect(message).to include("attach")
    end

    it "does not tell the caller how many words to remove" do
      expect(call_bug(cap: 1).errors.join).not_to match(/over by/i)
    end

    it "shows the per-field breakdown" do
      expect(call_bug(cap: 1).errors.join).to include("steps")
    end
  end
end
