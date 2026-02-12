# frozen_string_literal: true

require "open-uri"

class TrelloCli::Cli::Attach < Thor
  def self.exit_on_failure?
    true
  end

  desc "list REF", "List attachments on a card"
  def list(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)
    attachments = TrelloCli::Api::Attachment.list(client, card_id)

    if attachments.empty?
      say "No attachments"
      return
    end

    attachments.each do |att|
      say att["name"]
      say "  URL: #{att['url']}"
      say ""
    end
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "get REF FILENAME", "Download an attachment"
  option :output, type: :string, aliases: "-o", desc: "Output path (defaults to current directory)"
  def get(ref, filename)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    attachment = TrelloCli::Api::Attachment.find_by_name(client, card_id, filename)
    url = attachment["url"]

    output_path = options[:output] || File.join(Dir.pwd, filename)

    say "Downloading #{filename}..."

    download_url = "#{url}?key=#{config.api_key}&token=#{config.token}"

    URI.parse(download_url).open do |remote|
      File.binwrite(output_path, remote.read)
    end

    say "Saved to: #{output_path}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  rescue OpenURI::HTTPError => e
    say "Download failed: #{e.message}", :red
    exit 1
  end

  desc "upload REF FILE", "Upload a file as attachment"
  def upload(ref, file_path)
    unless File.exist?(file_path)
      say "Error: File not found: #{file_path}", :red
      exit 1
    end

    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    attachment = TrelloCli::Api::Attachment.upload(client, card_id, file_path)

    say "Uploaded: #{attachment['name']}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
