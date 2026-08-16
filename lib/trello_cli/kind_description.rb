# frozen_string_literal: true

# Assembles a card description from a kind's fields. Pure: no network, no config.
module TrelloCli
  class KindDescription
    CALLER_MARKER = /\A\s*(?:[-*+]|\d+[.)])\s+/.freeze

    def self.split_lines(value)
      Array(value)
        .flat_map { |element| element.to_s.split("\n") }
        .map { |line| line.sub(CALLER_MARKER, "").strip }
        .reject(&:empty?)
    end

    def self.sections(kind, values)
      TrelloCli::Kinds.fetch(kind)[:fields].filter_map do |field|
        body = render(field, values[field[:flag]])
        next if body.nil? || body.empty?

        { flag: field[:flag], text: "## #{field[:heading]}\n#{body}" }
      end
    end

    def self.build(kind, values)
      sections(kind, values).map { |section| section[:text] }.join("\n\n")
    end

    def self.render(field, value)
      return nil if value.nil?

      case field[:format]
      when :numbered
        split_lines(value).each_with_index.map { |line, i| "#{i + 1}. #{line}" }.join("\n")
      when :lines
        split_lines(value).join("\n")
      else
        # An Array reaching a text field must not be rendered with Array#to_s,
        # which would put a literal ["a", "b"] into the card description.
        value.is_a?(Array) ? split_lines(value).join("\n") : value.to_s.strip
      end
    end
    private_class_method :render
  end
end
