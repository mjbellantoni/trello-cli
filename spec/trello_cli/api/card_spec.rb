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
end
