# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

RSpec.describe "card update" do
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
    stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/42")
      .with(query: auth)
      .to_return(status: 200, body: { "id" => "card123", "idShort" => 42 }.to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:put, "https://api.trello.com/1/cards/card123")
      .with(query: auth)
      .to_return(status: 200, body: { "id" => "card123" }.to_json,
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

  def update_request
    a_request(:put, "https://api.trello.com/1/cards/card123").with(query: auth)
  end

  it "sets a due date given with --due" do
    run(["card", "update", "#42", "--due", "2026-09-15T17:00Z"])

    expect(update_request.with(body: { due: "2026-09-15T17:00:00Z" })).to have_been_made.once
  end

  it "accepts the -D alias for --due" do
    run(["card", "update", "#42", "-D", "2026-09-15T17:00Z"])

    expect(update_request.with(body: { due: "2026-09-15T17:00:00Z" })).to have_been_made.once
  end

  it "clears the due date with --due none" do
    run(["card", "update", "#42", "--due", "none"])

    expect(update_request.with(body: { due: nil })).to have_been_made.once
  end

  it "marks the due date complete with --due-complete" do
    run(["card", "update", "#42", "--due-complete"])

    expect(update_request.with(body: { dueComplete: true })).to have_been_made.once
  end

  it "marks the due date incomplete with --no-due-complete" do
    run(["card", "update", "#42", "--no-due-complete"])

    expect(update_request.with(body: { dueComplete: false })).to have_been_made.once
  end

  it "sets title, description and due in one request" do
    run(["card", "update", "#42", "-t", "New title", "-d", "New desc", "--due", "2026-09-15T17:00Z"])

    expect(
      update_request.with(body: { name: "New title", desc: "New desc", due: "2026-09-15T17:00:00Z" })
    ).to have_been_made.once
  end

  it "names the due date in the success message" do
    expect(run(["card", "update", "#42", "--due", "2026-09-15T17:00Z"])).to include("due date")
  end

  it "names due complete in the success message" do
    expect(run(["card", "update", "#42", "--due-complete"])).to include("due complete")
  end

  it "joins two updated fields with and" do
    expect(run(["card", "update", "#42", "-t", "New title", "-d", "New desc"]))
      .to include("Updated card description and title")
  end

  it "joins three updated fields as a list" do
    expect(run(["card", "update", "#42", "-t", "T", "-d", "D", "--due", "2026-09-15"]))
      .to include("Updated card description, title, and due date")
  end

  it "still updates the title alone" do
    run(["card", "update", "#42", "-t", "New title"])

    expect(update_request.with(body: { name: "New title" })).to have_been_made.once
  end

  it "reports an invalid due date and updates nothing" do
    expect { run(["card", "update", "#42", "--due", "whenever"]) }.to raise_error(SystemExit)

    expect(update_request).not_to have_been_made
  end

  it "refuses to run with no update options" do
    expect { run(["card", "update", "#42"]) }.to raise_error(SystemExit)

    expect(update_request).not_to have_been_made
  end

  it "lists every update flag when none is given" do
    out = StringIO.new
    original = $stdout
    $stdout = out
    begin
      TrelloCli::Cli.start(["card", "update", "#42"])
    rescue SystemExit
      nil
    ensure
      $stdout = original
    end

    expect(out.string).to match(/--description.*--title.*--due.*--due-complete/m)
  end
end
