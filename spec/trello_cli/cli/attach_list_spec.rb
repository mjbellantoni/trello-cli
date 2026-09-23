# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

# Pins what `attach list` prints. The output was previously unasserted, and
# `attach remove` is about to extend it with the attachment ID — without this,
# a change to the rendering could regress silently.
RSpec.describe "attach list" do
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
    stub_request(:get, "https://api.trello.com/1/boards/test_board/cards/42")
      .with(query: auth)
      .to_return(status: 200, body: { "id" => "card123" }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_attachments(payload)
    stub_request(:get, "https://api.trello.com/1/cards/card123/attachments")
      .with(query: auth)
      .to_return(status: 200, body: payload.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  # Runs the CLI the way a caller does, capturing what it prints.
  def list(ref = "#42")
    out = StringIO.new
    original = $stdout
    $stdout = out
    TrelloCli::Cli.start(["attach", "list", ref])
    out.string
  ensure
    $stdout = original
  end

  it "says so when the card has no attachments" do
    stub_attachments([])

    expect(list).to eq("No attachments\n")
  end

  it "prints each attachment's name, id and URL" do
    stub_attachments([
                       { "id" => "att1", "name" => "notes.pdf", "fileName" => "notes.pdf",
                         "url" => "https://trello.com/notes.pdf" },
                       { "id" => "att2", "name" => "design.png", "fileName" => "design.png",
                         "url" => "https://trello.com/design.png" }
                     ])

    expect(list).to eq(<<~OUT)
      notes.pdf
        ID: att1
        URL: https://trello.com/notes.pdf

      design.png
        ID: att2
        URL: https://trello.com/design.png

    OUT
  end
end
