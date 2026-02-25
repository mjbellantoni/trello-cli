# frozen_string_literal: true

require "json"

module TrelloCli
  class CommandCatalog
    SCHEMA_VERSION = "1"

    def self.generate
      new.generate
    end

    def generate
      {
        "schema_version" => SCHEMA_VERSION,
        "cli_version" => TrelloCli::VERSION,
        "commands" => build_commands
      }
    end

    private

    def build_commands
      commands = []

      TrelloCli::Cli.subcommand_classes.each do |sub_name, sub_class|
        sub_class.commands.each do |method_name, command|
          next if method_name == "help"

          cli_name = command.usage.split.first
          canonical = "#{sub_name} #{cli_name}"
          args = parse_args(command.usage)
          opts = build_options(command)

          commands << {
            "aliases" => [],
            "args" => args,
            "examples" => [build_example(canonical, args)],
            "name" => canonical,
            "options" => opts,
            "outputs" => ["text"],
            "summary" => command.description
          }
        end
      end

      commands.sort_by { |c| c["name"] }
    end

    def build_example(canonical, args)
      parts = ["trello", canonical]
      args.each { |a| parts << a["name"] }
      parts.join(" ")
    end

    def build_options(command)
      return [] unless command.options

      command.options.sort_by { |name, _| name }.map do |_name, opt|
        entry = {
          "name" => "--#{opt.name}",
          "required" => opt.required == true,
          "summary" => opt.description || "",
          "type" => opt.type.to_s
        }
        entry["aliases"] = opt.aliases if opt.aliases&.any?
        unless opt.default.nil? || (opt.default.respond_to?(:empty?) && opt.default.empty?)
          entry["default"] = opt.default
        end
        entry["enum"] = opt.enum if opt.respond_to?(:enum) && opt.enum&.any?
        entry
      end
    end

    def parse_args(usage)
      parts = usage.split[1..] || []
      parts.select { |p| p.match?(/\A[A-Z]/) }.map do |arg|
        { "name" => arg, "required" => true }
      end
    end
  end
end
