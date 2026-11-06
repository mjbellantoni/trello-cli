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

  describe ".cards" do
    before do
      stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
        .with(query: auth)
        .to_return(status: 200, body: [{ "id" => "l1", "name" => "Doing" }].to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "asks for the fields the card listing renders" do
      stub = stub_request(:get, "https://api.trello.com/1/lists/l1/cards")
             .with(query: auth.merge(fields: "idShort,name,labels"))
             .to_return(status: 200, body: [].to_json,
                        headers: { "Content-Type" => "application/json" })

      described_class.cards(client, config, "Doing")

      expect(stub).to have_been_made.once
    end

    it "asks for the fields the caller names" do
      stub = stub_request(:get, "https://api.trello.com/1/lists/l1/cards")
             .with(query: auth.merge(fields: "idShort,shortLink,pos"))
             .to_return(status: 200, body: [{ "id" => "c1", "idShort" => 42, "pos" => 1.0 }].to_json,
                        headers: { "Content-Type" => "application/json" })

      result = described_class.cards(client, config, "Doing", fields: "idShort,shortLink,pos")

      expect(stub).to have_been_made.once
      expect(result.first["pos"]).to eq(1.0)
    end
  end

  describe ".detailed_cards" do
    let(:detail_query) do
      auth.merge(fields: "idShort,name,desc,due,dueComplete,labels,shortUrl,idList,pos",
                 checklists: "all", members: "true", member_fields: "fullName,username",
                 attachments: "true", attachment_fields: "name,url")
    end

    def stub_get(path, query, body)
      stub_request(:get, "https://api.trello.com/1#{path}")
        .with(query: query)
        .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
    end

    let!(:lists_stub) do
      stub_get("/boards/test_board/lists", auth,
               [{ "id" => "l1", "name" => "Doing" }, { "id" => "l2", "name" => "Done" }])
    end

    # One request for the cards however many there are, plus the lists that
    # name and order them. Asking per card is what this read exists to avoid.
    it "reads every card on the board in two requests" do
      cards_stub = stub_get("/boards/test_board/cards", detail_query, [])

      described_class.detailed_cards(client, config)

      expect(lists_stub).to have_been_made.once
      expect(cards_stub).to have_been_made.once
    end

    it "orders cards by list as the board shows them, then by position" do
      stub_get("/boards/test_board/cards", detail_query,
               [{ "idShort" => 3, "idList" => "l2", "pos" => 1 },
                { "idShort" => 2, "idList" => "l1", "pos" => 20 },
                { "idShort" => 1, "idList" => "l1", "pos" => 10 }])

      result = described_class.detailed_cards(client, config)

      expect(result.map { |c| c["idShort"] }).to eq([1, 2, 3])
    end

    it "names each card's list the way a single card read does" do
      stub_get("/boards/test_board/cards", detail_query, [{ "idShort" => 1, "idList" => "l2", "pos" => 1 }])

      result = described_class.detailed_cards(client, config)

      expect(result.first["list"]).to eq({ "id" => "l2", "name" => "Done" })
    end

    it "reads only the named list's cards when given a name" do
      cards_stub = stub_get("/lists/l2/cards", detail_query, [{ "idShort" => 1, "idList" => "l2", "pos" => 1 }])

      result = described_class.detailed_cards(client, config, name: "Done")

      expect(cards_stub).to have_been_made.once
      expect(result.map { |c| c["list"]["name"] }).to eq(["Done"])
    end

    it "reports a named list that is not on the board" do
      expect { described_class.detailed_cards(client, config, name: "Someday") }
        .to raise_error(TrelloCli::NotFoundError, "List not found: Someday")
    end
  end
end
