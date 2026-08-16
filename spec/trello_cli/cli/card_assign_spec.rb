# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

RSpec.describe "card assign and unassign" do
  let(:auth) { { key: "test_key", token: "test_token" } }

  around do |example|
    saved = ENV.to_h.slice("TRELLO_API_KEY", "TRELLO_TOKEN", "TRELLO_DEFAULT_BOARD_ID")
    ENV["TRELLO_API_KEY"] = "test_key"
    ENV["TRELLO_TOKEN"] = "test_token"
    ENV["TRELLO_DEFAULT_BOARD_ID"] = "test_board"
    example.run
  ensure
    %w[TRELLO_API_KEY TRELLO_TOKEN TRELLO_DEFAULT_BOARD_ID].each { |k| ENV.delete(k) }
    saved.each { |k, v| ENV[k] = v }
  end

  before do
    stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/451")
      .with(query: auth)
      .to_return(status: 200, body: { "id" => "card123" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:get, "https://api.trello.com/1/boards/test_board/members")
      .with(query: auth.merge(fields: "id,username,fullName,initials"))
      .to_return(status: 200, body: [
        { "id" => "m1", "username" => "mjb", "fullName" => "Matthew Bellantoni", "initials" => "MB" },
        { "id" => "m2", "username" => "collinreed", "fullName" => "Collin Reed", "initials" => "CR" }
      ].to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_card_members(ids)
    stub_request(:get, "https://api.trello.com/1/cards/card123")
      .with(query: auth.merge(fields: "idMembers"))
      .to_return(status: 200, body: { "idMembers" => ids }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def run(argv)
    out = StringIO.new
    original = $stdout
    $stdout = out
    TrelloCli::Cli.start(argv)
    out.string
  ensure
    $stdout = original
  end

  describe "assign" do
    before do
      stub_request(:post, "https://api.trello.com/1/cards/card123/idMembers")
        .with(query: auth, body: { value: "m2" }.to_json)
        .to_return(status: 200, body: [{ "id" => "m2" }].to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "assigns a member found by username" do
      stub_card_members([])

      expect(run(%w[card assign #451 collinreed])).to eq("Assigned: Collin Reed (collinreed)\n")
    end

    it "assigns a member found by partial identity such as initials" do
      stub_card_members([])
      run(%w[card assign #451 cr])

      expect(
        a_request(:post, "https://api.trello.com/1/cards/card123/idMembers")
          .with(query: auth, body: { value: "m2" }.to_json)
      ).to have_been_made.once
    end

    # Agents retry. A second assign must not be a failure.
    it "reports success without re-posting when the member is already assigned" do
      stub_card_members(%w[m2])

      expect(run(%w[card assign #451 collinreed])).to eq("Assigned: Collin Reed (collinreed)\n")
      expect(a_request(:post, "https://api.trello.com/1/cards/card123/idMembers")).not_to have_been_made
    end

    it "exits 1 and names the roster when the member does not exist" do
      stub_card_members([])

      expect { run(%w[card assign #451 nobody]) }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end

    it "does not post anything when the member does not exist" do
      stub_card_members([])
      begin
        run(%w[card assign #451 nobody])
      rescue SystemExit
        nil
      end

      expect(a_request(:post, "https://api.trello.com/1/cards/card123/idMembers")).not_to have_been_made
    end
  end

  describe "unassign" do
    before do
      stub_request(:delete, "https://api.trello.com/1/cards/card123/idMembers/m2")
        .with(query: auth)
        .to_return(status: 200, body: [].to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "removes the member from the card" do
      expect(run(%w[card unassign #451 collinreed])).to eq("Unassigned: Collin Reed (collinreed)\n")
    end

    it "resolves the member the same way assign does" do
      run(["card", "unassign", "#451", "Collin Reed"])

      expect(
        a_request(:delete, "https://api.trello.com/1/cards/card123/idMembers/m2").with(query: auth)
      ).to have_been_made.once
    end

    it "exits 1 when the member does not exist" do
      expect { run(%w[card unassign #451 nobody]) }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end
  end
end
