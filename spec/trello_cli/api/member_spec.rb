# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::Member do
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

  let(:members) do
    [{ "id" => "m1", "username" => "mjb", "fullName" => "Matthew Bellantoni", "initials" => "MB" },
     { "id" => "m2", "username" => "collinreed", "fullName" => "Collin Reed", "initials" => "CR" }]
  end

  before do
    stub_request(:get, "https://api.trello.com/1/boards/test_board/members")
      .with(query: auth.merge(fields: "id,username,fullName,initials"))
      .to_return(status: 200, body: members.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  describe ".find_by_name" do
    it "matches a username" do
      expect(described_class.find_by_name(client, config, "collinreed")["id"]).to eq("m2")
    end

    it "matches a username regardless of case" do
      expect(described_class.find_by_name(client, config, "CollinReed")["id"]).to eq("m2")
    end

    it "matches a full name" do
      expect(described_class.find_by_name(client, config, "Collin Reed")["id"]).to eq("m2")
    end

    it "matches a full name regardless of case" do
      expect(described_class.find_by_name(client, config, "collin reed")["id"]).to eq("m2")
    end

    it "matches initials" do
      expect(described_class.find_by_name(client, config, "cr")["id"]).to eq("m2")
    end

    # Username is the identifier Trello guarantees is unique, so it has to win.
    # Initials collide freely and a full name can equal someone else's username.
    it "prefers a username match over a full name or initials match" do
      stub_request(:get, "https://api.trello.com/1/boards/test_board/members")
        .with(query: auth.merge(fields: "id,username,fullName,initials"))
        .to_return(status: 200, body: [
          { "id" => "m1", "username" => "ambiguous", "fullName" => "Someone Else", "initials" => "SE" },
          { "id" => "m2", "username" => "other", "fullName" => "ambiguous", "initials" => "AM" }
        ].to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.find_by_name(client, config, "ambiguous")["id"]).to eq("m1")
    end

    # Real usernames carry noise a caller will not type: collinstewart12,
    # matthew_rl. Exact-only matching makes the obvious guess fail.
    it "matches a username by prefix" do
      expect(described_class.find_by_name(client, config, "collin")["id"]).to eq("m2")
    end

    it "matches a full name by prefix" do
      expect(described_class.find_by_name(client, config, "Matthew")["id"]).to eq("m1")
    end

    # An exact hit must never be shadowed by someone else's longer name.
    it "prefers an exact match over a prefix match" do
      stub_request(:get, "https://api.trello.com/1/boards/test_board/members")
        .with(query: auth.merge(fields: "id,username,fullName,initials"))
        .to_return(status: 200, body: [
          { "id" => "m1", "username" => "samantha", "fullName" => "Samantha Ray", "initials" => "SR" },
          { "id" => "m2", "username" => "sam", "fullName" => "Sam Patel", "initials" => "SP" }
        ].to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.find_by_name(client, config, "sam")["id"]).to eq("m2")
    end

    it "refuses an ambiguous prefix rather than guessing" do
      stub_request(:get, "https://api.trello.com/1/boards/test_board/members")
        .with(query: auth.merge(fields: "id,username,fullName,initials"))
        .to_return(status: 200, body: [
          { "id" => "m1", "username" => "collinstewart12", "fullName" => "Collin Stewart", "initials" => "CS" },
          { "id" => "m2", "username" => "collinsmith", "fullName" => "Collin Smith", "initials" => "CS" }
        ].to_json, headers: { "Content-Type" => "application/json" })

      expect { described_class.find_by_name(client, config, "collin") }
        .to raise_error(TrelloCli::Error, <<~MESSAGE.strip)
          Member is ambiguous: collin
          Matches:
            collinstewart12 Collin Stewart
            collinsmith     Collin Smith
        MESSAGE
    end

    it "raises NotFoundError when nobody matches" do
      expect { described_class.find_by_name(client, config, "nobody") }
        .to raise_error(TrelloCli::NotFoundError)
    end

    # A caller who guessed wrong needs the roster to guess right, and there is
    # no other command that prints it.
    it "lists the board roster in the error so the caller can correct itself" do
      expect { described_class.find_by_name(client, config, "nobody") }
        .to raise_error(TrelloCli::NotFoundError, <<~MESSAGE.strip)
          Member not found: nobody
          Board members:
            mjb        Matthew Bellantoni
            collinreed Collin Reed
        MESSAGE
    end

    it "handles a board with no members" do
      stub_request(:get, "https://api.trello.com/1/boards/test_board/members")
        .with(query: auth.merge(fields: "id,username,fullName,initials"))
        .to_return(status: 200, body: [].to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { described_class.find_by_name(client, config, "anyone") }
        .to raise_error(TrelloCli::NotFoundError, "Member not found: anyone\nBoard members: (none)")
    end
  end

  describe ".describe" do
    it "renders a full name with the username in parentheses" do
      expect(described_class.describe(members[1])).to eq("Collin Reed (collinreed)")
    end

    it "falls back to the username alone when there is no full name" do
      expect(described_class.describe("username" => "ghost", "fullName" => "")).to eq("ghost")
    end
  end
end
