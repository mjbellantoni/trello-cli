# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

RSpec.describe "card new" do
  let(:auth) { { key: "test_key", token: "test_token" } }

  around do |example|
    saved = ENV.to_h.slice("TRELLO_API_KEY", "TRELLO_TOKEN", "TRELLO_DEFAULT_BOARD_ID", "TRELLO_DEFAULT_LIST")
    ENV["TRELLO_API_KEY"] = "test_key"
    ENV["TRELLO_TOKEN"] = "test_token"
    ENV["TRELLO_DEFAULT_BOARD_ID"] = "test_board"
    ENV["TRELLO_DEFAULT_LIST"] = "Inbox"
    example.run
  ensure
    %w[TRELLO_API_KEY TRELLO_TOKEN TRELLO_DEFAULT_BOARD_ID TRELLO_DEFAULT_LIST].each { |k| ENV.delete(k) }
    saved.each { |k, v| ENV[k] = v }
  end

  before do
    stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
      .with(query: auth)
      .to_return(status: 200, body: [{ "id" => "list1", "name" => "Inbox" }].to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:get, "https://api.trello.com/1/boards/test_board/labels")
      .with(query: auth)
      .to_return(status: 200,
                 body: [{ "id" => "l1", "name" => "bug", "color" => "red" },
                        { "id" => "l2", "name" => "feature", "color" => "green" },
                        { "id" => "l3", "name" => "chore", "color" => "blue" }].to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.trello.com/1/cards")
      .with(query: auth)
      .to_return(status: 200,
                 body: { "id" => "c1", "idShort" => 451, "name" => "A card",
                         "shortUrl" => "https://trello.com/c/abc123" }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def run(argv)
    out = StringIO.new
    original = $stdout
    $stdout = out
    TrelloCli::Cli.start(argv)
  ensure
    $stdout = original
  end

  it "accumulates repeated --label flags" do
    run(["card", "new", "A card", "--label", "bug", "--label", "chore"])

    expect(
      a_request(:post, "https://api.trello.com/1/cards")
        .with(query: auth, body: hash_including("idLabels" => "l1,l3"))
    ).to have_been_made.once
  end

  it "still accepts several labels after a single flag" do
    run(["card", "new", "A card", "--label", "bug", "chore"])

    expect(
      a_request(:post, "https://api.trello.com/1/cards")
        .with(query: auth, body: hash_including("idLabels" => "l1,l3"))
    ).to have_been_made.once
  end

  it "creates a card with no labels when none are given" do
    run(["card", "new", "A card"])

    expect(
      a_request(:post, "https://api.trello.com/1/cards").with(query: auth) { |req|
        !JSON.parse(req.body).key?("idLabels")
      }
    ).to have_been_made.once
  end
end
