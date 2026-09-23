# frozen_string_literal: true

class TrelloCli::Api::Attachment
  def self.list(client, card_id)
    client.get("/cards/#{card_id}/attachments")
  end

  def self.download(client, card_id, attachment)
    file_name = attachment["fileName"]
    raise TrelloCli::Error, "Attachment '#{attachment['name']}' is a link, not an uploaded file" unless file_name

    path = "/cards/#{card_id}/attachments/#{attachment['id']}/download/#{URI.encode_www_form_component(file_name)}"
    client.download_file(path)
  end

  def self.find_by_name(client, card_id, filename)
    attachments = list(client, card_id)
    attachment = attachments.find { |a| a["fileName"] == filename || a["name"] == filename }
    raise TrelloCli::NotFoundError, "Attachment not found: #{filename}" unless attachment

    attachment
  end

  def self.upload(client, card_id, file_path)
    name = File.basename(file_path)
    client.post_multipart("/cards/#{card_id}/attachments", file: file_path, name: name)
  end

  def self.remove(client, card_id, attachment_id)
    client.delete("/cards/#{card_id}/attachments/#{attachment_id}")
  end

  # Resolves the attachment a caller named, for operations where picking the
  # wrong one matters. An exact id wins outright; otherwise the name must match
  # exactly one attachment, because a card may hold several with the same name.
  def self.find_by_reference(client, card_id, reference)
    attachments = list(client, card_id)

    by_id = attachments.find { |a| a["id"] == reference }
    return by_id if by_id

    matches = attachments.select { |a| a["fileName"] == reference || a["name"] == reference }
    raise TrelloCli::NotFoundError, "Attachment not found: #{reference}" if matches.empty?
    raise TrelloCli::Error, ambiguous_message(reference, matches) if matches.size > 1

    matches.first
  end

  def self.ambiguous_message(reference, matches)
    lines = matches.map do |a|
      date = a["date"].to_s[0, 10]
      date.empty? ? "  #{a['id']}" : "  #{a['id']} (added #{date})"
    end

    "#{matches.size} attachments on this card are named '#{reference}':\n" \
      "#{lines.join("\n")}\n" \
      "Re-run with the attachment ID instead of the name."
  end
  private_class_method :ambiguous_message
end
