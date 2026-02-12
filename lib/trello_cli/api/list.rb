# frozen_string_literal: true

class TrelloCli::Api::List
  def self.find_by_name(client, config, name)
    lists = client.get("/boards/#{config.board_id}/lists")
    list = lists.find { |l| l["name"] == name }
    raise TrelloCli::NotFoundError, "List not found: #{name}" unless list

    list
  end

  def self.all(client, config)
    client.get("/boards/#{config.board_id}/lists")
  end
end
