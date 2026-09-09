# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::Card do
  let(:config) do
    instance_double(
      TrelloCli::Api::Config,
      api_key: "test_key",
      token: "test_token",
      board_id: "test_board"
    )
  end
  let(:client) { TrelloCli::Api::Client.new(config) }

  describe ".add_label" do
    before do
      # Stub card lookup by short number
      stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/42")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: { "id" => "card123", "idShort" => 42 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub board labels lookup
      stub_request(:get, "https://api.trello.com/1/boards/test_board/labels")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: [
            { "id" => "label1", "name" => "Bug", "color" => "red" },
            { "id" => "label2", "name" => "Feature", "color" => "blue" }
          ].to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub adding label to card
      stub_request(:post, "https://api.trello.com/1/cards/card123/idLabels")
        .with(
          query: { key: "test_key", token: "test_token" },
          body: { value: "label1" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(
          status: 200,
          body: [{ "id" => "label1", "name" => "Bug", "color" => "red" }].to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "adds a label to the card by name" do
      result = described_class.add_label(client, config, "#42", "Bug")
      expect(result).to be_an(Array)
    end

    it "matches label name case-insensitively" do
      result = described_class.add_label(client, config, "#42", "bug")
      expect(result).to be_an(Array)
    end

    it "raises NotFoundError for unknown label" do
      expect {
        described_class.add_label(client, config, "#42", "Nonexistent")
      }.to raise_error(TrelloCli::NotFoundError, /Label not found/)
    end
  end

  describe ".resolve_labels" do
    before do
      stub_request(:get, "https://api.trello.com/1/boards/test_board/labels")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: [
            { "id" => "label1", "name" => "\u{1F41B} Bug", "color" => "red" }
          ].to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "matches label names with multibyte characters when input is ASCII-8BIT" do
      ascii_name = "\u{1F41B} Bug".dup.force_encoding("ASCII-8BIT")
      result = described_class.resolve_labels(client, config, [ascii_name])
      expect(result).to eq(["label1"])
    end
  end

  describe ".remove_label" do
    before do
      # Stub card lookup by short number
      stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/42")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: { "id" => "card123", "idShort" => 42 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub card fetch (to get current labels)
      stub_request(:get, "https://api.trello.com/1/cards/card123")
        .with(query: hash_including(key: "test_key", token: "test_token"))
        .to_return(
          status: 200,
          body: {
            "id" => "card123",
            "labels" => [
              { "id" => "label1", "name" => "Bug", "color" => "red" },
              { "id" => "label2", "name" => "Feature", "color" => "blue" }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub removing label from card
      stub_request(:delete, "https://api.trello.com/1/cards/card123/idLabels/label1")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: { "_value" => nil }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "removes a label from the card by name" do
      described_class.remove_label(client, config, "#42", "Bug")
      expect(
        a_request(:delete, "https://api.trello.com/1/cards/card123/idLabels/label1")
          .with(query: { key: "test_key", token: "test_token" })
      ).to have_been_made.once
    end

    it "matches label name case-insensitively" do
      described_class.remove_label(client, config, "#42", "bug")
      expect(
        a_request(:delete, "https://api.trello.com/1/cards/card123/idLabels/label1")
          .with(query: { key: "test_key", token: "test_token" })
      ).to have_been_made.once
    end

    it "raises NotFoundError when card doesn't have the label" do
      expect {
        described_class.remove_label(client, config, "#42", "Urgent")
      }.to raise_error(TrelloCli::NotFoundError, /Label not found on card/)
    end
  end

  describe ".create" do
    before do
      # Stub board lists lookup (used by List.find_by_name)
      stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: [{ "id" => "list1", "name" => "Inbox" }].to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub the card creation
      stub_request(:post, "https://api.trello.com/1/cards")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: { "id" => "card123", "idShort" => 42 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "places the card at the top when position is top" do
      described_class.create(client, config, title: "T", list: "Inbox", position: "top")
      expect(
        a_request(:post, "https://api.trello.com/1/cards")
          .with(query: { key: "test_key", token: "test_token" },
                body: { name: "T", idList: "list1", idBoard: "test_board", pos: "top" })
      ).to have_been_made.once
    end

    it "sends a numeric position as a number" do
      described_class.create(client, config, title: "T", list: "Inbox", position: "2")
      expect(
        a_request(:post, "https://api.trello.com/1/cards")
          .with(query: { key: "test_key", token: "test_token" },
                body: { name: "T", idList: "list1", idBoard: "test_board", pos: 2.0 })
      ).to have_been_made.once
    end

    it "raises Error for an invalid position" do
      expect {
        described_class.create(client, config, title: "T", list: "Inbox", position: "abc")
      }.to raise_error(TrelloCli::Error, /position/i)
    end

    it "sends a due date as an ISO 8601 UTC string" do
      described_class.create(client, config, title: "T", list: "Inbox", due: "2026-09-15T17:00Z")
      expect(
        a_request(:post, "https://api.trello.com/1/cards")
          .with(query: { key: "test_key", token: "test_token" },
                body: { name: "T", idList: "list1", idBoard: "test_board", due: "2026-09-15T17:00:00Z" })
      ).to have_been_made.once
    end

    it "omits due when no due date is given" do
      described_class.create(client, config, title: "T", list: "Inbox")
      expect(
        a_request(:post, "https://api.trello.com/1/cards")
          .with(query: { key: "test_key", token: "test_token" },
                body: { name: "T", idList: "list1", idBoard: "test_board" })
      ).to have_been_made.once
    end

    it "raises Error for an invalid due date" do
      expect {
        described_class.create(client, config, title: "T", list: "Inbox", due: "whenever")
      }.to raise_error(TrelloCli::Error, /due date/i)
    end
  end

  describe ".move" do
    before do
      # Stub card lookup by short number
      stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/42")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: { "id" => "card123", "idShort" => 42 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub board lists lookup (used by List.find_by_name)
      stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: [{ "id" => "list1", "name" => "Done" }].to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub the card update
      stub_request(:put, "https://api.trello.com/1/cards/card123")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: { "id" => "card123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "moves a card to a list without changing position" do
      described_class.move(client, config, "#42", "Done")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { idList: "list1" })
      ).to have_been_made.once
    end

    it "places the card at the top when position is top" do
      described_class.move(client, config, "#42", "Done", position: "top")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { idList: "list1", pos: "top" })
      ).to have_been_made.once
    end

    it "places the card at the bottom when position is bottom" do
      described_class.move(client, config, "#42", "Done", position: "bottom")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { idList: "list1", pos: "bottom" })
      ).to have_been_made.once
    end

    it "sends a numeric position as a number" do
      described_class.move(client, config, "#42", "Done", position: "2")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { idList: "list1", pos: 2.0 })
      ).to have_been_made.once
    end

    it "raises Error for an invalid position" do
      expect {
        described_class.move(client, config, "#42", "Done", position: "abc")
      }.to raise_error(TrelloCli::Error, /position/i)
    end
  end

  describe ".update" do
    before do
      # Stub card lookup by short number
      stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/42")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: { "id" => "card123", "idShort" => 42 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub the card update
      stub_request(:put, "https://api.trello.com/1/cards/card123")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(
          status: 200,
          body: { "id" => "card123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "updates the description" do
      described_class.update(client, config, "#42", description: "New desc")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { desc: "New desc" })
      ).to have_been_made.once
    end

    it "updates the title" do
      described_class.update(client, config, "#42", name: "New title")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { name: "New title" })
      ).to have_been_made.once
    end

    it "updates both description and title in one request" do
      described_class.update(client, config, "#42", description: "New desc", name: "New title")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { desc: "New desc", name: "New title" })
      ).to have_been_made.once
    end

    it "sets the due date as an ISO 8601 UTC string" do
      described_class.update(client, config, "#42", due: "2026-09-15T17:00Z")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { due: "2026-09-15T17:00:00Z" })
      ).to have_been_made.once
    end

    it "sends a null due date for none" do
      described_class.update(client, config, "#42", due: "none")
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { due: nil })
      ).to have_been_made.once
    end

    it "marks the due date complete" do
      described_class.update(client, config, "#42", due_complete: true)
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { dueComplete: true })
      ).to have_been_made.once
    end

    it "marks the due date incomplete" do
      described_class.update(client, config, "#42", due_complete: false)
      expect(
        a_request(:put, "https://api.trello.com/1/cards/card123")
          .with(query: { key: "test_key", token: "test_token" }, body: { dueComplete: false })
      ).to have_been_made.once
    end

    it "raises Error for an invalid due date" do
      expect {
        described_class.update(client, config, "#42", due: "whenever")
      }.to raise_error(TrelloCli::Error, /due date/i)
    end
  end
end
