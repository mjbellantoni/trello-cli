# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::List do
  let(:config) do
    instance_double(
      TrelloCli::Api::Config,
      api_key: "test_key",
      token: "test_token",
      board_id: "test_board"
    )
  end
  let(:client) { TrelloCli::Api::Client.new(config) }
  let(:auth) { { key: "test_key", token: "test_token" } }

  describe ".all" do
    it "returns the board's open lists" do
      stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
        .with(query: auth)
        .to_return(status: 200,
                   body: [{ "id" => "l1", "name" => "Inbox" },
                          { "id" => "l2", "name" => "By Aug 30" }].to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.all(client, config).map { |l| l["name"] }).to eq(["Inbox", "By Aug 30"])
    end

    it "does not ask for embedded cards when counts are not wanted" do
      stub = stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
             .with(query: auth)
             .to_return(status: 200, body: [].to_json,
                        headers: { "Content-Type" => "application/json" })

      described_class.all(client, config)

      expect(stub).to have_been_made.once
    end

    # The count has to arrive on the same request. Asking per list would turn
    # one call into one-per-list on a board with dozens of them.
    it "embeds minimal open cards in the same request when counts are wanted" do
      stub = stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
             .with(query: auth.merge(cards: "open", card_fields: "id"))
             .to_return(status: 200,
                        body: [{ "id" => "l1", "name" => "Inbox",
                                 "cards" => [{ "id" => "c1" }, { "id" => "c2" }] }].to_json,
                        headers: { "Content-Type" => "application/json" })

      result = described_class.all(client, config, with_counts: true)

      expect(stub).to have_been_made.once
      expect(result.first["cards"].size).to eq(2)
    end
  end
end
