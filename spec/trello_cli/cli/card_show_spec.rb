# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

# Pins what `card show` prints. The command renders six optional sections in a
# fixed order, and every one of them was previously unasserted — a change to the
# rendering or to the fields Card.find requests could regress any of them
# silently.
RSpec.describe "card show" do
  let(:auth) { { key: "test_key", token: "test_token" } }
  let(:find_query) do
    auth.merge(checklists: "all", attachments: "true", actions: "commentCard", list: "true", members: "true")
  end

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
  end

  def stub_card(payload)
    stub_request(:get, "https://api.trello.com/1/cards/card123")
      .with(query: find_query)
      .to_return(status: 200, body: payload.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  # Runs the CLI the way a caller does, capturing what it prints.
  def show(ref = "#451")
    out = StringIO.new
    original = $stdout
    $stdout = out
    TrelloCli::Cli.start(["card", "show", ref])
    out.string
  ensure
    $stdout = original
  end

  describe "a card with every section populated" do
    before do
      stub_card(
        "name" => "Export times out on large ranges",
        "shortUrl" => "https://trello.com/c/abc123XY",
        "list" => { "id" => "list9", "name" => "Needs a Decision" },
        "members" => [{ "username" => "collinreed", "fullName" => "Collin Reed" }],
        "labels" => [{ "name" => "bug" }, { "name" => "urgent" }],
        "desc" => "The spinner hangs and returns a 504.",
        "checklists" => [{
          "name" => "Steps",
          "checkItems" => [
            { "name" => "second", "state" => "incomplete", "pos" => 2 },
            { "name" => "first", "state" => "complete", "pos" => 1 }
          ]
        }],
        "attachments" => [{ "name" => "design.md" }],
        "actions" => [
          { "date" => "2026-08-14T10:00:00.000Z", "data" => { "text" => "short one" } },
          { "date" => "2026-08-13T10:00:00.000Z", "data" => { "text" => "a" * 100 } },
          { "date" => "2026-08-12T10:00:00.000Z", "data" => { "text" => "line\n\nbreaks   here" } },
          { "date" => "2026-08-11T10:00:00.000Z", "data" => { "text" => "fourth, never shown" } }
        ]
      )
    end

    it "renders every section in order" do
      expect(show).to eq(<<~OUTPUT)
        Export times out on large ranges
        URL: https://trello.com/c/abc123XY
        List: Needs a Decision
        Members: Collin Reed

        Labels: bug, urgent

        Description:
        The spinner hangs and returns a 504.

        Checklists:
          Steps: (1/2)
            [x] first
            [ ] second

        Attachments:
          - design.md

        Comments (3 most recent):
          Aug 14: short one
          Aug 13: #{'a' * 77}...
          Aug 12: line breaks here
      OUTPUT
    end

    it "orders checklist items by pos, not by array order" do
      expect(show).to match(/\[x\] first\n\s+\[ \] second/)
    end

    it "shows at most three comments" do
      expect(show).not_to include("fourth, never shown")
    end

    it "truncates a comment over 80 characters to 77 plus an ellipsis" do
      line = show.lines.find { |l| l.include?("Aug 13") }
      expect(line.split(": ", 2).last.strip.length).to eq(80)
    end

    it "collapses whitespace inside a comment onto one line" do
      expect(show).to include("Aug 12: line breaks here")
    end
  end

  describe "a card with nothing but a title and a list" do
    before do
      stub_card(
        "name" => "Bare card",
        "shortUrl" => "https://trello.com/c/bare1234",
        "list" => { "id" => "list1", "name" => "Inbox" },
        "members" => [],
        "labels" => [],
        "desc" => "",
        "checklists" => [],
        "attachments" => [],
        "actions" => []
      )
    end

    it "prints the title, URL and list, omitting the empty members line" do
      expect(show).to eq("Bare card\nURL: https://trello.com/c/bare1234\nList: Inbox\n\n")
    end
  end

  describe "members" do
    it "joins several members with commas" do
      stub_card(
        "name" => "Shared", "shortUrl" => "https://trello.com/c/shared12",
        "list" => { "name" => "In Progress" },
        "members" => [{ "username" => "mjb", "fullName" => "Matthew Bellantoni" },
                      { "username" => "collinreed", "fullName" => "Collin Reed" }]
      )

      expect(show).to include("Members: Matthew Bellantoni, Collin Reed\n")
    end

    it "falls back to the username when a member has no full name" do
      stub_card(
        "name" => "Shared", "shortUrl" => "https://trello.com/c/shared12",
        "list" => { "name" => "In Progress" },
        "members" => [{ "username" => "ghost", "fullName" => "" }]
      )

      expect(show).to include("Members: ghost\n")
    end
  end

  # Trello returns `due` in UTC; show renders it in the caller's local zone, so
  # these examples pin a zone. The dates are far enough from today that overdue
  # is decided without freezing the clock.
  describe "due dates" do
    around do |example|
      saved = ENV["TZ"]
      ENV["TZ"] = "America/New_York"
      example.run
    ensure
      ENV["TZ"] = saved
    end

    def stub_due(due, due_complete: false)
      stub_card("name" => "Dated", "shortUrl" => "https://trello.com/c/dated123",
                "list" => { "name" => "Inbox" },
                "due" => due, "dueComplete" => due_complete)
    end

    it "renders the due date in local time after the list" do
      stub_due("2099-09-15T16:00:00.000Z")

      expect(show).to include("List: Inbox\nDue: Sep 15, 2099 12:00pm\n")
    end

    it "marks a past due date overdue" do
      stub_due("2020-01-01T14:00:00.000Z")

      expect(show).to include("Due: Jan 1, 2020 9:00am (overdue)\n")
    end

    it "marks a completed due date complete rather than overdue" do
      stub_due("2020-01-01T14:00:00.000Z", due_complete: true)

      expect(show).to include("Due: Jan 1, 2020 9:00am (complete)\n")
    end

    it "does not call a future due date overdue" do
      stub_due("2099-09-15T16:00:00.000Z")

      expect(show).not_to include("overdue")
    end

    it "omits the due line when the card has no due date" do
      stub_card("name" => "Dateless", "shortUrl" => "https://trello.com/c/none1234",
                "list" => { "name" => "Inbox" }, "due" => nil)

      expect(show).not_to include("Due:")
    end
  end

  # The API omits `list` for a card that has been archived out of every list,
  # and show must not blow up rendering one.
  describe "a card with no list in the payload" do
    before do
      stub_card("name" => "Orphan", "shortUrl" => "https://trello.com/c/orphan12")
    end

    it "omits the list line rather than raising" do
      expect(show).to eq("Orphan\nURL: https://trello.com/c/orphan12\n\n")
    end
  end

  describe "a checklist with no items" do
    before do
      stub_card(
        "name" => "Empty checklist",
        "shortUrl" => "https://trello.com/c/empty123",
        "checklists" => [{ "name" => "Steps", "checkItems" => [] }]
      )
    end

    # Thor's `say` suppresses the newline when a message ends in whitespace, so
    # the empty progress counter leaves the line open. Pinned as-is: it is the
    # current behaviour, and anything appended after it would land on this line.
    it "renders the checklist name with an empty, unterminated progress counter" do
      expect(show).to eq("Empty checklist\nURL: https://trello.com/c/empty123\n\n\nChecklists:\n  Steps: ")
    end
  end

  describe "a card that does not exist" do
    before do
      stub_request(:get, "https://api.trello.com/1/cards/card123")
        .with(query: find_query)
        .to_return(status: 404, body: "not found")
    end

    it "exits non-zero" do
      expect { show }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end
  end
end
