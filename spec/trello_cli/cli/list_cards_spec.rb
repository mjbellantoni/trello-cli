# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

RSpec.describe "list cards" do
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

  def json_response(body)
    { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  def stub_lists
    stub_request(:get, "https://api.trello.com/1/boards/test_board/lists")
      .with(query: auth)
      .to_return(json_response([{ "id" => "l1", "name" => "Doing" }, { "id" => "l2", "name" => "Done" }]))
  end

  def stub_cards(cards)
    stub_request(:get, "https://api.trello.com/1/lists/l1/cards")
      .with(query: auth.merge(fields: "idShort,name,labels"))
      .to_return(json_response(cards))
  end

  # Runs the CLI the way a caller does, capturing output and exit status.
  def run(*argv)
    out = StringIO.new
    original = $stdout
    $stdout = out
    begin
      TrelloCli::Cli.start(["list", "cards", *argv])
      status = 0
    rescue SystemExit => e
      status = e.status
    end
    [out.string, status]
  ensure
    $stdout = original
  end

  let(:cards) do
    [{ "idShort" => 7, "name" => "Fix login", "labels" => [{ "name" => "Bug" }] },
     { "idShort" => 9, "name" => "Add export", "labels" => [{ "name" => "Feature" }] },
     { "idShort" => 12, "name" => "Tidy specs", "labels" => [] }]
  end

  before do
    stub_lists
    stub_cards(cards)
  end

  it "prints the number and name of each card by default" do
    expect(run("Doing")).to eq(["#7 Fix login\n#9 Add export\n#12 Tidy specs\n", 0])
  end

  it "prints only numbers with --format id" do
    expect(run("Doing", "--format", "id")).to eq(["#7\n#9\n#12\n", 0])
  end

  it "prints only names with --format name" do
    expect(run("Doing", "--format", "name")).to eq(["Fix login\nAdd export\nTidy specs\n", 0])
  end

  it "keeps only cards carrying the --with-label label, ignoring case" do
    expect(run("Doing", "--with-label", "bug")).to eq(["#7 Fix login\n", 0])
  end

  it "drops cards carrying the --without-label label, ignoring case" do
    expect(run("Doing", "--without-label", "FEATURE")).to eq(["#7 Fix login\n#12 Tidy specs\n", 0])
  end

  it "refuses --with-label and --without-label together" do
    output, status = run("Doing", "--with-label", "Bug", "--without-label", "Feature")

    expect(output).to include("Error: --with-label and --without-label are mutually exclusive")
    expect(status).to eq(1)
  end

  it "reports a list that is not on the board" do
    output, status = run("Someday")

    expect(output).to include("Error: List not found: Someday")
    expect(status).to eq(1)
  end
end
