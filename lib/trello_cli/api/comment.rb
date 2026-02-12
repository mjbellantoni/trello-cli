# frozen_string_literal: true

class TrelloCli::Api::Comment
  def self.list(client, card_id)
    client.get("/cards/#{card_id}/actions", { filter: "commentCard" })
  end

  def self.add(client, card_id, text)
    raise ArgumentError, "Comment text cannot be empty" if text.nil? || text.strip.empty?

    client.post("/cards/#{card_id}/actions/comments", { text: text })
  end
end
