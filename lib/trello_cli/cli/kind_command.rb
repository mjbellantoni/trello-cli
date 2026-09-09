# frozen_string_literal: true

# Generates one Thor subcommand class per entry in the kind registry. Every
# rejection happens before the first HTTP call, so a refused card never reaches
# Trello. There is deliberately no bypass flag — see the design document.
class TrelloCli::Cli::KindCommand
  LIST_FORMATS = %i[numbered lines].freeze

  # Fields rendered as a list take a Thor :array option. Those are declared
  # `repeatable`, so Thor collects each occurrence of the flag into its own
  # array: `--steps A B --steps C` arrives as [["A", "B"], ["C"]]. Callers
  # flatten it, which leaves the single-flag form untouched.
  def self.list_field?(field)
    LIST_FORMATS.include?(field[:format])
  end

  def self.build(kind)
    definition = TrelloCli::Kinds.fetch(kind)

    Class.new(Thor) do
      define_singleton_method(:exit_on_failure?) { true }

      desc "new TITLE", definition[:summary]
      definition[:fields].each do |field|
        list = TrelloCli::Cli::KindCommand.list_field?(field)
        method_option field[:flag],
                      type: list ? :array : :string,
                      repeatable: list,
                      required: field[:required],
                      desc: field[:desc]
      end
      method_option :list, type: :string, aliases: "-l", desc: "List name (defaults to config default_list)"
      method_option :label, type: :array, aliases: "-L", repeatable: true, default: [],
                    desc: "Extra labels, one per value: --label A B or --label A --label B"
      method_option :position, type: :string, aliases: "-p", desc: "Position in target list (top, bottom, or a number)"
      method_option :due, type: :string, aliases: "-D",
                    desc: "Due date: YYYY-MM-DD, YYYY-MM-DDTHH:MM, today, tomorrow, +Nd, or +Nw"

      define_method(:new) do |title|
        config = TrelloCli::Api::Config.load
        values = definition[:fields].to_h do |f|
          raw = options[f[:flag].to_s]
          [f[:flag], TrelloCli::Cli::KindCommand.list_field?(f) ? Array(raw).flatten : raw]
        end

        result = TrelloCli::KindValidator.call(
          kind: kind, title: title, values: values, cap: config.word_cap_for(kind)
        )

        unless result.ok?
          result.errors.each { |message| say_error message, :red }
          exit 1
        end

        client = TrelloCli::Api::Client.new(config)
        card = TrelloCli::Api::Card.create(
          client, config,
          title: title,
          description: result.description,
          list: options[:list],
          labels: [config.label_for(kind)] + Array(options[:label]).flatten,
          position: options[:position] || "top",
          due: options[:due]
        )

        say "Created: #{card['shortUrl']}", :green
        say "Card ##{card['idShort']}: #{card['name']}" if card["idShort"]
      rescue TrelloCli::Error => e
        say_error "Error: #{e.message}", :red
        exit 1
      end
    end
  end
end
