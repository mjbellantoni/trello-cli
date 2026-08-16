# frozen_string_literal: true

# Declarative description of each card kind: its fields, the headings they
# render under, its label, and its word cap. Headings match the conventions in
# the file-bug / file-feature / file-chore skills verbatim, because the board
# already holds hundreds of cards in that format.
module TrelloCli
  class Kinds
    REGISTRY = {
      bug: {
        summary: "Create a new bug card",
        fields: [
          { flag: :steps, heading: "Steps to Recreate", required: true, format: :numbered,
            desc: "Steps to recreate, one per value (repeatable)" },
          { flag: :expected, heading: "Expected Behavior", required: true, format: :text,
            desc: "What should have happened" },
          { flag: :actual, heading: "Actual Behavior", required: true, format: :text,
            desc: "What actually happened" },
          { flag: :notes, heading: "Notes", required: false, format: :text,
            desc: "Links and evidence only" }
        ]
      },
      feature: {
        summary: "Create a new feature card",
        gherkin: true,
        fields: [
          { flag: :what, heading: "What", required: true, format: :text,
            desc: "The capability, in one or two sentences" },
          { flag: :why, heading: "Why", required: true, format: :text,
            desc: "Who wants it and what it unblocks" },
          { flag: :done_when, heading: "Done when", required: true, format: :lines,
            desc: "Given/When/Then acceptance criteria (repeatable)" },
          { flag: :notes, heading: "Notes", required: false, format: :text,
            desc: "Links and evidence only" }
        ]
      },
      chore: {
        summary: "Create a new chore card",
        fields: [
          { flag: :what, heading: "What", required: true, format: :text,
            desc: "The work, in one or two sentences" },
          { flag: :why_now, heading: "Why now", required: true, format: :text,
            desc: "What makes this worth doing now" },
          { flag: :done_when, heading: "Done when", required: true, format: :lines,
            desc: "Observable completion condition (repeatable)" },
          { flag: :notes, heading: "Notes", required: false, format: :text,
            desc: "Links and evidence only" }
        ]
      }
    }.freeze

    def self.names
      REGISTRY.keys
    end

    def self.fetch(kind)
      REGISTRY.fetch(kind) { raise TrelloCli::Error, "Unknown kind: #{kind}" }
    end
  end
end
