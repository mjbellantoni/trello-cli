# frozen_string_literal: true

class TrelloCli::Api::Attachment
  def self.list(client, card_id)
    client.get("/cards/#{card_id}/attachments")
  end

  def self.download_url(client, card_id, attachment_id)
    attachment = client.get("/cards/#{card_id}/attachments/#{attachment_id}")
    attachment["url"]
  end

  def self.find_by_name(client, card_id, filename)
    attachments = list(client, card_id)
    attachment = attachments.find { |a| a["name"] == filename }
    raise TrelloCli::NotFoundError, "Attachment not found: #{filename}" unless attachment

    attachment
  end

  def self.upload(client, card_id, file_path)
    name = File.basename(file_path)
    client.post_multipart("/cards/#{card_id}/attachments", file: file_path, name: name)
  end
end
