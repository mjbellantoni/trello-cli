# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::Placement do
  let(:config) do
    instance_double(
      TrelloCli::Api::Config,
      api_key: "test_key",
      token: "test_token",
      board_id: "test_board",
      default_list: "Inbox"
    )
  end
  let(:client) { TrelloCli::Api::Client.new(config) }
  let(:auth) { { key: "test_key", token: "test_token" } }

  # Three cards, evenly spaced the way Trello spaces them.
  let(:cards) do
    [{ "id" => "c1", "idShort" => 10, "shortLink" => "aaa111", "pos" => 65_536.0 },
     { "id" => "c2", "idShort" => 20, "shortLink" => "bbb222", "pos" => 131_072.0 },
     { "id" => "c3", "idShort" => 30, "shortLink" => "ccc333", "pos" => 196_608.0 }]
  end

  before do
    stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
      .with(query: auth)
      .to_return(status: 200,
                 body: [{ "id" => "l1", "name" => "Doing" }, { "id" => "l2", "name" => "Inbox" }].to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:get, "https://api.trello.com/1/lists/l1/cards")
      .with(query: auth.merge(fields: "idShort,shortLink,pos"))
      .to_return(status: 200, body: cards.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  describe ".resolve" do
    it "returns nothing when no anchor is asked for" do
      expect(described_class.resolve(client, config, "Doing", after: nil)).to be_nil
    end

    it "places the card at the midpoint between the anchor and the card below it" do
      placement = described_class.resolve(client, config, "Doing", after: "#20")

      expect(placement.pos).to eq(163_840.0)
    end

    it "reports the anchor by card number" do
      placement = described_class.resolve(client, config, "Doing", after: "#20")

      expect(placement.anchor_number).to eq(20)
    end

    it "sends the card to the bottom when the anchor is last" do
      placement = described_class.resolve(client, config, "Doing", after: "#30")

      expect(placement.pos).to eq("bottom")
    end

    it "finds the anchor by short link" do
      placement = described_class.resolve(client, config, "Doing", after: "bbb222")

      expect(placement.pos).to eq(163_840.0)
    end

    it "finds the anchor by card URL" do
      placement = described_class.resolve(client, config, "Doing", after: "https://trello.com/c/bbb222/x")

      expect(placement.pos).to eq(163_840.0)
    end

    it "orders by pos rather than by the order the API returned" do
      cards.reverse!

      placement = described_class.resolve(client, config, "Doing", after: "#20")

      expect(placement.pos).to eq(163_840.0)
    end

    it "falls back to the default list when no list is named" do
      stub = stub_request(:get, "https://api.trello.com/1/lists/l2/cards")
             .with(query: auth.merge(fields: "idShort,shortLink,pos"))
             .to_return(status: 200, body: cards.to_json,
                        headers: { "Content-Type" => "application/json" })

      described_class.resolve(client, config, nil, after: "#20")

      expect(stub).to have_been_made.once
    end

    # CardRef raises ArgumentError, which no command rescues; it has to reach
    # the caller as the error the CLI knows how to print.
    it "raises a CLI error for an empty anchor" do
      expect {
        described_class.resolve(client, config, "Doing", after: "")
      }.to raise_error(TrelloCli::Error, /empty/)
    end

    it "raises when the anchor is not in the target list" do
      expect {
        described_class.resolve(client, config, "Doing", after: "#99")
      }.to raise_error(TrelloCli::NotFoundError, /not in list "Doing": #99/)
    end

    it "raises when the anchor is the card being moved" do
      expect {
        described_class.resolve(client, config, "Doing", after: "#20", moving: "#20")
      }.to raise_error(TrelloCli::Error, /itself/)
    end

    it "recognises the card being moved through a different kind of reference" do
      expect {
        described_class.resolve(client, config, "Doing", after: "#20", moving: "bbb222")
      }.to raise_error(TrelloCli::Error, /itself/)
    end

    it "rejects an anchor and a position together before making any request" do
      expect {
        described_class.resolve(client, config, "Doing", after: "#20", position: "top")
      }.to raise_error(TrelloCli::Error, /--after and --position/)

      expect(a_request(:get, "https://api.trello.com/1/boards/test_board/lists")).not_to have_been_made
    end

    # The moved card's own pos must not decide where it lands.
    it "ignores the card being moved when choosing the follower" do
      placement = described_class.resolve(client, config, "Doing", after: "#10", moving: "#20")

      expect(placement.pos).to eq(131_072.0)
    end

    it "sends the card to the bottom when only the moved card follows the anchor" do
      placement = described_class.resolve(client, config, "Doing", after: "#20", moving: "#30")

      expect(placement.pos).to eq("bottom")
    end
  end

  # Trello lists can carry duplicate pos values after bulk imports and some
  # sort operations. Cards tied with the anchor have no defined order among
  # themselves, so "after the anchor" can only mean after the whole tie.
  describe "tied positions" do
    context "when the anchor is tied with the card below it" do
      let(:cards) do
        [{ "id" => "c1", "idShort" => 10, "shortLink" => "aaa111", "pos" => 100.0 },
         { "id" => "c2", "idShort" => 20, "shortLink" => "bbb222", "pos" => 100.0 },
         { "id" => "c3", "idShort" => 30, "shortLink" => "ccc333", "pos" => 200.0 }]
      end

      it "places the card past the tie rather than inside it" do
        placement = described_class.resolve(client, config, "Doing", after: "#10")

        expect(placement.pos).to eq(150.0)
      end
    end

    context "when the tie runs to the end of the list" do
      let(:cards) do
        [{ "id" => "c1", "idShort" => 10, "shortLink" => "aaa111", "pos" => 100.0 },
         { "id" => "c2", "idShort" => 20, "shortLink" => "bbb222", "pos" => 100.0 }]
      end

      it "sends the card to the bottom" do
        placement = described_class.resolve(client, config, "Doing", after: "#10")

        expect(placement.pos).to eq("bottom")
      end
    end
  end
end
