# frozen_string_literal: true

class TrelloCli::Cli::Comment < Thor
  def self.exit_on_failure?
    true
  end

  desc "list REF", "List comments on a card"
  def list(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)
    comments = TrelloCli::Api::Comment.list(client, card_id)

    if comments.empty?
      say "No comments"
      return
    end

    comments.each do |comment|
      date = Time.parse(comment["date"]).strftime("%b %d, %Y %H:%M")
      author = comment.dig("memberCreator", "fullName") || "Unknown"
      text = comment.dig("data", "text") || ""

      say "--- #{date} | #{author} ---"
      say text
      say ""
    end
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "add REF TEXT", "Add a comment to a card"
  def add(ref, text)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    TrelloCli::Api::Comment.add(client, card_id, text)

    say "Comment added", :green
  rescue ArgumentError => e
    say "Error: #{e.message}", :red
    exit 1
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
