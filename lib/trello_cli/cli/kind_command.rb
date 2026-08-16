# frozen_string_literal: true

# Generates one Thor subcommand class per entry in the kind registry. Every
# rejection happens before the first HTTP call, so a refused card never reaches
# Trello. There is deliberately no bypass flag — see the design document.
class TrelloCli::Cli::KindCommand
  def self.build(kind)
    definition = TrelloCli::Kinds.fetch(kind)

    Class.new(Thor) do
      define_singleton_method(:exit_on_failure?) { true }

      desc "new TITLE", definition[:summary]
      definition[:fields].each do |field|
        method_option field[:flag],
                      type: %i[numbered lines].include?(field[:format]) ? :array : :string,
                      required: field[:required],
                      desc: field[:desc]
      end
      method_option :list, type: :string, aliases: "-l", desc: "List name (defaults to config default_list)"
      method_option :label, type: :array, aliases: "-L", default: [], desc: "Extra labels (repeatable)"
      method_option :position, type: :string, aliases: "-p", desc: "Position in target list (top, bottom, or a number)"

      define_method(:new) do |title|
        config = TrelloCli::Api::Config.load
        values = definition[:fields].to_h { |f| [f[:flag], options[f[:flag].to_s]] }

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
          labels: [config.label_for(kind)] + Array(options[:label]),
          position: options[:position] || "top"
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
