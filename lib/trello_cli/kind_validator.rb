# frozen_string_literal: true

# Decides whether a kind card may be created. Pure: no network, no config.
# Every failure is collected, so a caller learns all of its problems at once.
module TrelloCli
  class KindValidator
    Result = Struct.new(:errors, :description, :word_count, :breakdown, keyword_init: true) do
      def ok?
        errors.empty?
      end
    end

    KIND_PREFIX = /\A\s*(?:bug|feature|chore)\s*:/i.freeze
    GHERKIN = %w[given when then].freeze

    def self.call(kind:, title:, values:, cap:)
      definition = TrelloCli::Kinds.fetch(kind)
      sections = TrelloCli::KindDescription.sections(kind, values)
      description = TrelloCli::KindDescription.build(kind, values)
      breakdown = sections.map { |s| [s[:flag], TrelloCli::WordCount.count(s[:text])] }
      count = TrelloCli::WordCount.count(description)

      errors = []
      errors << missing_error(kind, definition, values)
      errors << prefix_error(title)
      errors << gherkin_error(definition, values)
      errors << cap_error(kind, count, cap, breakdown)

      Result.new(errors: errors.compact, description: description,
                 word_count: count, breakdown: breakdown)
    end

    def self.blank?(value)
      # Blankness is judged the same way for every format. Special-casing by
      # declared format let an Array through a text field: [].to_s is "[]", which
      # is not empty, so a required field supplied as [] passed validation.
      TrelloCli::KindDescription.split_lines(value).empty?
    end

    def self.missing_error(kind, definition, values)
      missing = definition[:fields].select { |f| f[:required] && blank?(values[f[:flag]]) }
      return nil if missing.empty?

      required = definition[:fields].select { |f| f[:required] }.map { |f| flag_of(f) }
      "Error: #{kind} new requires #{required.join(', ')}.\n" \
        "Missing: #{missing.map { |f| flag_of(f) }.join(', ')}\n" \
        "No card created."
    end

    def self.prefix_error(title)
      return nil unless title.to_s.match?(KIND_PREFIX)

      "Error: title starts with a kind prefix — the label carries the kind.\n" \
        "Use a plain sentence describing the change.\n" \
        "No card created."
    end

    def self.gherkin_error(definition, values)
      return nil unless definition[:gherkin]

      text = TrelloCli::KindDescription.split_lines(values[:done_when]).join(" ").downcase
      # Word boundaries, not substrings: "strengthen" contains "then",
      # "whenever" contains "when", and "forgiven" contains "given", so
      # include? accepted prose with no Gherkin structure whatsoever.
      return nil if GHERKIN.all? { |word| text.match?(/\b#{word}\b/) }

      "Error: --done-when must contain Given, When, and Then.\n" \
        "No card created."
    end

    def self.cap_error(kind, count, cap, breakdown)
      return nil if count <= cap

      "Error: #{kind} description is #{count} words, over the #{cap}-word cap.\n" \
        "  #{breakdown.map { |(flag, n)| "#{flag} #{n}" }.join(' | ')}\n" \
        "Over the cap means one of two things:\n" \
        "  - it is more than one card, so split it\n" \
        "  - the detail belongs in an attachment: trello attach upload\n" \
        "No card created."
    end

    def self.flag_of(field)
      "--#{field[:flag].to_s.tr('_', '-')}"
    end

    private_class_method :blank?, :missing_error, :prefix_error, :gherkin_error, :cap_error, :flag_of
  end
end
