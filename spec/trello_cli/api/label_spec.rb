# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::Label do
  let(:config) do
    instance_double(TrelloCli::Api::Config, api_key: "test_key", token: "test_token", board_id: "test_board")
  end
  let(:client) { TrelloCli::Api::Client.new(config) }
  let(:auth) { { key: "test_key", token: "test_token" } }

  def stub_labels(labels)
    stub_request(:get, "https://api.trello.com/1/boards/test_board/labels")
      .with(query: auth)
      .to_return(status: 200, body: labels.to_json, headers: { "Content-Type" => "application/json" })
  end

  before do
    stub_labels([{ "id" => "l1", "name" => "bug", "color" => "red" },
                 { "id" => "l2", "name" => "", "color" => "sky" }])
  end

  describe ".find_by_name" do
    it "finds a label case-insensitively" do
      expect(described_class.find_by_name(client, config, "BUG")["id"]).to eq("l1")
    end

    it "raises when the label does not exist" do
      expect {
        described_class.find_by_name(client, config, "nope")
      }.to raise_error(TrelloCli::NotFoundError, /nope/)
    end
  end

  describe ".create" do
    it "posts a new label" do
      stub_request(:post, "https://api.trello.com/1/labels")
        .with(query: auth).to_return(status: 200, body: { "id" => "l9" }.to_json,
                                     headers: { "Content-Type" => "application/json" })

      described_class.create(client, config, name: "chore", color: "blue")

      expect(
        a_request(:post, "https://api.trello.com/1/labels")
          .with(query: auth, body: { name: "chore", color: "blue", idBoard: "test_board" })
      ).to have_been_made.once
    end

    it "refuses a duplicate name" do
      expect {
        described_class.create(client, config, name: "Bug", color: "blue")
      }.to raise_error(TrelloCli::Error, /already exists/i)
    end

    it "allows a colour-only label even though an unnamed label exists" do
      stub_request(:post, "https://api.trello.com/1/labels")
        .with(query: auth).to_return(status: 200, body: { "id" => "l9" }.to_json,
                                     headers: { "Content-Type" => "application/json" })

      expect { described_class.create(client, config, name: "", color: "pink") }.not_to raise_error
    end
  end

  describe ".rename" do
    it "refuses to rename onto an existing name" do
      stub_labels([{ "id" => "l1", "name" => "bug", "color" => "red" },
                   { "id" => "l2", "name" => "chore", "color" => "blue" }])
      expect {
        described_class.rename(client, config, "bug", "chore")
      }.to raise_error(TrelloCli::Error, /already exists/i)
    end
  end

  describe ".delete" do
    def stub_board_cards(cards)
      stub_request(:get, "https://api.trello.com/1/boards/test_board/cards")
        .with(query: hash_including(auth))
        .to_return(status: 200, body: cards.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "deletes a label that is on no cards" do
      stub_board_cards([{ "id" => "c1", "labels" => [] }])
      stub_request(:delete, "https://api.trello.com/1/labels/l1")
        .with(query: auth).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      described_class.delete(client, config, "bug")

      expect(a_request(:delete, "https://api.trello.com/1/labels/l1").with(query: auth)).to have_been_made.once
    end

    it "refuses to delete a label that is in use" do
      stub_board_cards([{ "id" => "c1", "labels" => [{ "id" => "l1" }] }])
      expect {
        described_class.delete(client, config, "bug")
      }.to raise_error(TrelloCli::Error, /1 card/)
    end

    it "names the environment override rather than a flag" do
      stub_board_cards([{ "id" => "c1", "labels" => [{ "id" => "l1" }] }])
      expect {
        described_class.delete(client, config, "bug")
      }.to raise_error(TrelloCli::Error, /TRELLO_ALLOW_LABEL_DELETE_IN_USE/)
    end

    it "deletes an in-use label when the override is set" do
      stub_board_cards([{ "id" => "c1", "labels" => [{ "id" => "l1" }] }])
      stub_request(:delete, "https://api.trello.com/1/labels/l1")
        .with(query: auth).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      ENV["TRELLO_ALLOW_LABEL_DELETE_IN_USE"] = "true"
      described_class.delete(client, config, "bug")

      expect(a_request(:delete, "https://api.trello.com/1/labels/l1").with(query: auth)).to have_been_made.once
    ensure
      ENV.delete("TRELLO_ALLOW_LABEL_DELETE_IN_USE")
    end

    it "counts archived cards as usage when deciding whether to refuse" do
      stub_board_cards([{ "id" => "c1", "labels" => [{ "id" => "l1" }] }])

      expect { described_class.delete(client, config, "bug") }.to raise_error(TrelloCli::Error)

      expect(
        a_request(:get, "https://api.trello.com/1/boards/test_board/cards")
          .with(query: hash_including("filter" => "all"))
      ).to have_been_made
    end
  end
end
