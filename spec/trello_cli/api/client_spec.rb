# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::Client do
  let(:config) do
    instance_double(
      TrelloCli::Api::Config,
      api_key: "test_key",
      token: "test_token",
      board_id: "test_board"
    )
  end
  let(:client) { described_class.new(config) }

  describe "#get" do
    let(:response_body) { { "id" => "123", "name" => "Test" }.to_json }

    before do
      stub_request(:get, "https://api.trello.com/1/boards/test_board")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "makes authenticated GET request" do
      result = client.get("/boards/test_board")
      expect(result).to eq({ "id" => "123", "name" => "Test" })
    end

    context "when response is 401" do
      before do
        stub_request(:get, "https://api.trello.com/1/boards/test_board")
          .with(query: { key: "test_key", token: "test_token" })
          .to_return(status: 401, body: "unauthorized")
      end

      it "raises AuthError" do
        expect { client.get("/boards/test_board") }.to raise_error(TrelloCli::AuthError)
      end
    end

    context "when response is 404" do
      before do
        stub_request(:get, "https://api.trello.com/1/boards/test_board")
          .with(query: { key: "test_key", token: "test_token" })
          .to_return(status: 404, body: "not found")
      end

      it "raises NotFoundError" do
        expect { client.get("/boards/test_board") }.to raise_error(TrelloCli::NotFoundError)
      end
    end
  end

  describe "#post" do
    let(:response_body) { { "id" => "new123" }.to_json }

    before do
      stub_request(:post, "https://api.trello.com/1/cards")
        .with(
          query: { key: "test_key", token: "test_token" },
          body: { name: "Test Card" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "makes authenticated POST request with JSON body" do
      result = client.post("/cards", { name: "Test Card" })
      expect(result).to eq({ "id" => "new123" })
    end
  end

  describe "#delete" do
    let(:response_body) { { "_value" => nil }.to_json }

    before do
      stub_request(:delete, "https://api.trello.com/1/checklists/cl123")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "makes authenticated DELETE request" do
      result = client.delete("/checklists/cl123")
      expect(result).to eq({ "_value" => nil })
    end
  end
end
