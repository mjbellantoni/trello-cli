# frozen_string_literal: true

# A card as a script reads it: what card show prints, under names this CLI
# owns rather than Trello's, so a change in Trello's payload cannot reach a
# caller. Every key is always present.
class TrelloCli::CardJson
  def self.from(card)
    {
      "number" => card["idShort"],
      "name" => card["name"],
      "list" => card.dig("list", "name"),
      "url" => card["shortUrl"],
      "due" => card["due"],
      "due_complete" => card["dueComplete"] == true,
      "labels" => (card["labels"] || []).map { |l| l["name"] },
      "members" => (card["members"] || []).map { |m| TrelloCli::Api::Member.display_name(m) },
      "description" => card["desc"].to_s,
      "checklists" => (card["checklists"] || []).map { |c| checklist(c) },
      "attachments" => (card["attachments"] || []).map { |a| a.slice("name", "url") }
    }
  end

  def self.checklist(checklist)
    items = (checklist["checkItems"] || []).sort_by { |i| i["pos"] || 0 }
    { "name" => checklist["name"],
      "items" => items.map { |i| { "name" => i["name"], "complete" => i["state"] == "complete" } } }
  end
  private_class_method :checklist
end
