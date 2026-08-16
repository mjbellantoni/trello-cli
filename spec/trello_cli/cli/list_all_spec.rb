# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

RSpec.describe "list all" do
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

  def stub_lists(query_extra = {}, body:)
    stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
      .with(query: auth.merge(query_extra))
      .to_return(status: 200, body: body.to_json,
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

  let(:plain_lists) do
    [{ "id" => "abc111", "name" => "Inbox" },
     { "id" => "abc222", "name" => "By Aug 30" },
     { "id" => "abc333", "name" => "Needs a Decision" }]
  end

  it "prints one list name per line by default" do
    stub_lists(body: plain_lists)

    expect(run(%w[list all])).to eq("Inbox\nBy Aug 30\nNeeds a Decision\n")
  end

  it "preserves board order rather than sorting" do
    stub_lists(body: plain_lists.reverse)

    expect(run(%w[list all])).to eq("Needs a Decision\nBy Aug 30\nInbox\n")
  end

  it "prints ids with --format id" do
    stub_lists(body: plain_lists)

    expect(run(%w[list all --format id])).to eq("abc111\nabc222\nabc333\n")
  end

  it "prints id and name with --format id-name" do
    stub_lists(body: plain_lists)

    expect(run(%w[list all --format id-name])).to eq("abc111 Inbox\nabc222 By Aug 30\nabc333 Needs a Decision\n")
  end

  it "appends the open card count with --count" do
    stub_lists({ cards: "open", card_fields: "id" }, body: [
                 { "id" => "abc111", "name" => "Inbox", "cards" => [{ "id" => "c1" }, { "id" => "c2" }] },
                 { "id" => "abc222", "name" => "By Aug 30", "cards" => [] }
               ])

    expect(run(%w[list all --count])).to eq("Inbox (2)\nBy Aug 30 (0)\n")
  end

  it "combines --count with --format" do
    stub_lists({ cards: "open", card_fields: "id" }, body: [
                 { "id" => "abc111", "name" => "Inbox", "cards" => [{ "id" => "c1" }] }
               ])

    expect(run(%w[list all --format id-name --count])).to eq("abc111 Inbox (1)\n")
  end

  it "prints nothing when the board has no lists" do
    stub_lists(body: [])

    expect(run(%w[list all])).to eq("")
  end

  it "exits 1 when the API rejects the request" do
    stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
      .with(query: auth)
      .to_return(status: 401, body: "unauthorized")

    expect { run(%w[list all]) }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
  end
end
