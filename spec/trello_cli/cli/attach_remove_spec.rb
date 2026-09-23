# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

RSpec.describe "attach remove" do
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

  def stub_delete(attachment_id)
    stub_request(:delete, "https://api.trello.com/1/cards/card123/attachments/#{attachment_id}")
      .with(query: auth)
      .to_return(status: 200, body: { "limits" => {} }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def delete_request(attachment_id)
    a_request(:delete, "https://api.trello.com/1/cards/card123/attachments/#{attachment_id}").with(query: auth)
  end

  # Runs the CLI the way a caller does, capturing output and exit status.
  def remove(ref, identifier)
    out = StringIO.new
    original = $stdout
    $stdout = out
    begin
      TrelloCli::Cli.start(["attach", "remove", ref, identifier])
      status = 0
    rescue SystemExit => e
      status = e.status
    end
    [out.string, status]
  ensure
    $stdout = original
  end

  it "deletes the attachment matching the given file name" do
    stub_attachments([{ "id" => "att1", "name" => "notes.pdf", "fileName" => "notes.pdf" }])
    stub_delete("att1")

    output, status = remove("#42", "notes.pdf")

    expect(delete_request("att1")).to have_been_made.once
    expect(output).to eq("Removed attachment: notes.pdf\n")
    expect(status).to eq(0)
  end

  it "refuses to delete when the name matches more than one attachment" do
    stub_attachments([
                       { "id" => "att1", "name" => "notes.pdf", "fileName" => "notes.pdf",
                         "date" => "2026-09-01T10:00:00.000Z" },
                       { "id" => "att2", "name" => "notes.pdf", "fileName" => "notes.pdf",
                         "date" => "2026-09-14T11:30:00.000Z" }
                     ])

    output, status = remove("#42", "notes.pdf")

    expect(output).to eq(<<~OUT)
      Error: 2 attachments on this card are named 'notes.pdf':
        att1 (added 2026-09-01)
        att2 (added 2026-09-14)
      Re-run with the attachment ID instead of the name.
    OUT
    expect(status).to eq(1)
    expect(a_request(:delete, %r{/attachments/})).not_to have_been_made
  end

  it "deletes by attachment id, the escape hatch from an ambiguous name" do
    stub_attachments([
                       { "id" => "att1", "name" => "notes.pdf", "fileName" => "notes.pdf",
                         "date" => "2026-09-01T10:00:00.000Z" },
                       { "id" => "att2", "name" => "notes.pdf", "fileName" => "notes.pdf",
                         "date" => "2026-09-14T11:30:00.000Z" }
                     ])
    stub_delete("att2")

    output, status = remove("#42", "att2")

    expect(delete_request("att2")).to have_been_made.once
    expect(delete_request("att1")).not_to have_been_made
    expect(output).to eq("Removed attachment: notes.pdf\n")
    expect(status).to eq(0)
  end

  it "reports an error when no attachment matches" do
    stub_attachments([{ "id" => "att1", "name" => "notes.pdf", "fileName" => "notes.pdf" }])

    output, status = remove("#42", "ghost.pdf")

    expect(output).to eq("Error: Attachment not found: ghost.pdf\n")
    expect(status).to eq(1)
    expect(a_request(:delete, %r{/attachments/})).not_to have_been_made
  end

  # Guards the precedence rule: an argument is treated as an id only when it
  # exactly matches one. Short-circuiting on anything that *looks* like an id
  # (a 24-char hex string, say) would break this card's file and fail here.
  it "matches by name when a file is itself named like an attachment id" do
    stub_attachments([{ "id" => "att1", "name" => "61b7c9e4a1d2f3b8c7e60142",
                        "fileName" => "61b7c9e4a1d2f3b8c7e60142" }])
    stub_delete("att1")

    output, status = remove("#42", "61b7c9e4a1d2f3b8c7e60142")

    expect(delete_request("att1")).to have_been_made.once
    expect(output).to eq("Removed attachment: 61b7c9e4a1d2f3b8c7e60142\n")
    expect(status).to eq(0)
  end
end
