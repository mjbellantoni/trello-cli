# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

RSpec.describe "card move" do
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
      .to_return(status: 200,
                 body: [{ "id" => "l1", "name" => "Doing" }, { "id" => "l2", "name" => "Inbox" }].to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/7")
      .with(query: auth)
      .to_return(status: 200, body: { "id" => "card7" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:get, "https://api.trello.com/1/lists/l1/cards")
      .with(query: auth.merge(fields: "idShort,shortLink,pos"))
      .to_return(status: 200,
                 body: [{ "id" => "c1", "idShort" => 10, "shortLink" => "aaa111", "pos" => 65_536.0 },
                        { "id" => "c2", "idShort" => 20, "shortLink" => "bbb222", "pos" => 131_072.0 }].to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:get, "https://api.trello.com/1/lists/l2/cards")
      .with(query: auth.merge(fields: "idShort,shortLink,pos"))
      .to_return(status: 200,
                 body: [{ "id" => "c9", "idShort" => 90, "shortLink" => "zzz999", "pos" => 65_536.0 }].to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:put, "https://api.trello.com/1/cards/card7")
      .with(query: auth)
      .to_return(status: 200, body: { "id" => "card7" }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  # Runs the CLI the way a caller does, capturing output and exit status.
  def move(*argv)
    out = StringIO.new
    original = $stdout
    $stdout = out
    begin
      TrelloCli::Cli.start(["card", "move", *argv])
      status = 0
    rescue SystemExit => e
      status = e.status
    end
    [out.string, status]
  ensure
    $stdout = original
  end

  def put_request
    a_request(:put, "https://api.trello.com/1/cards/card7").with(query: auth)
  end

  it "sends the midpoint between the anchor and the card below it" do
    move("#7", "Doing", "--after", "#10")

    expect(
      put_request.with(body: hash_including("idList" => "l1", "pos" => 98_304.0))
    ).to have_been_made.once
  end

  it "reports where the card landed" do
    output, status = move("#7", "Doing", "--after", "#10")

    expect(status).to eq(0)
    expect(output).to include("Moved to: Doing")
    expect(output).to include("Placed after #10")
  end

  it "sends bottom when the anchor is the last card" do
    move("#7", "Doing", "--after", "#20")

    expect(put_request.with(body: hash_including("pos" => "bottom"))).to have_been_made.once
  end

  it "accepts the -a alias" do
    move("#7", "Doing", "-a", "#10")

    expect(put_request.with(body: hash_including("pos" => 98_304.0))).to have_been_made.once
  end

  it "refuses an anchor that is in another list, and moves nothing" do
    output, status = move("#7", "Doing", "--after", "#90")

    expect(status).to eq(1)
    expect(output).to include('Card not in list "Doing": #90')
    expect(put_request).not_to have_been_made
  end

  it "refuses to place a card after itself, and moves nothing" do
    stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/10")
      .with(query: auth)
      .to_return(status: 200, body: { "id" => "c1" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    output, status = move("#10", "Doing", "--after", "#10")

    expect(status).to eq(1)
    expect(output).to include("Cannot place a card after itself")
    expect(a_request(:put, %r{https://api\.trello\.com/1/cards/})).not_to have_been_made
  end

  it "refuses --after together with --position, and moves nothing" do
    output, status = move("#7", "Doing", "--after", "#10", "--position", "top")

    expect(status).to eq(1)
    expect(output).to include("--after and --position cannot be used together")
    expect(put_request).not_to have_been_made
  end

  it "still honours --position on its own" do
    move("#7", "Doing", "--position", "top")

    expect(put_request.with(body: hash_including("pos" => "top"))).to have_been_made.once
  end
end
