# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"

RSpec.describe TrelloCli::Cli::KindCommand do
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
                 body: { "id" => "c1", "idShort" => 451, "name" => "Export times out",
                         "shortUrl" => "https://trello.com/c/abc123" }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  # Runs the CLI the way a caller does. Returns the exit status: 0 when the
  # command returns normally, otherwise the status it exited with.
  def run(argv)
    TrelloCli::Cli.start(argv)
    0
  rescue SystemExit => e
    e.status
  end

  def valid_bug_argv
    ["bug", "new", "Export times out",
     "--steps", "Open Reports", "Click Export",
     "--expected", "CSV downloads.",
     "--actual", "Spinner hangs."]
  end

  describe "a valid bug" do
    it "exits zero" do
      expect(run(valid_bug_argv)).to eq(0)
    end

    it "creates the card at the top of the default list with the kind label" do
      run(valid_bug_argv)
      expect(
        a_request(:post, "https://api.trello.com/1/cards").with(query: auth, body: hash_including(
          "idList" => "list1", "pos" => "top", "idLabels" => "l1"
        ))
      ).to have_been_made.once
    end

    it "sends the assembled description" do
      run(valid_bug_argv)
      expect(
        a_request(:post, "https://api.trello.com/1/cards").with(query: auth) { |req|
          JSON.parse(req.body)["desc"].include?("## Steps to Recreate\n1. Open Reports\n2. Click Export")
        }
      ).to have_been_made.once
    end
  end

  describe "a valid feature" do
    let(:argv) do
      ["feature", "new", "Let reviewers filter the queue",
       "--what", "A filter control on the review queue",
       "--why", "Reviewers cannot find their own work",
       "--done-when", "Given a shared queue", "When I filter by my name", "Then only my cards remain"]
    end

    it "exits zero" do
      expect(run(argv)).to eq(0)
    end

    it "applies the feature label and sends the gherkin lines" do
      run(argv)
      expect(
        a_request(:post, "https://api.trello.com/1/cards").with(query: auth) { |req|
          body = JSON.parse(req.body)
          body["idLabels"] == "l2" &&
            body["desc"].include?("## Done when\nGiven a shared queue\nWhen I filter by my name\nThen only my cards remain")
        }
      ).to have_been_made.once
    end
  end

  describe "a valid chore" do
    let(:argv) do
      ["chore", "new", "Drop the unused legacy_sessions table",
       "--what", "Remove the table and its model",
       "--why-now", "It blocks the session-store migration",
       "--done-when", "The table is gone and no code references it"]
    end

    it "exits zero" do
      expect(run(argv)).to eq(0)
    end

    it "applies the chore label and uses the chore headings" do
      run(argv)
      expect(
        a_request(:post, "https://api.trello.com/1/cards").with(query: auth) { |req|
          body = JSON.parse(req.body)
          body["idLabels"] == "l3" &&
            body["desc"].include?("## Why now\nIt blocks the session-store migration")
        }
      ).to have_been_made.once
    end
  end

  describe "rejection" do
    it "exits 1 when the description is over the cap" do
      ENV["TRELLO_BUG_WORD_CAP"] = "5"
      expect(run(valid_bug_argv)).to eq(1)
    ensure
      ENV.delete("TRELLO_BUG_WORD_CAP")
    end

    it "creates no card when the description is over the cap" do
      ENV["TRELLO_BUG_WORD_CAP"] = "5"
      run(valid_bug_argv)
      expect(a_request(:post, "https://api.trello.com/1/cards")).not_to have_been_made
    ensure
      ENV.delete("TRELLO_BUG_WORD_CAP")
    end

    it "exits 1 for a kind-prefixed title" do
      argv = valid_bug_argv.dup
      argv[2] = "Bug: export times out"
      expect(run(argv)).to eq(1)
    end

    it "creates no card for a kind-prefixed title" do
      argv = valid_bug_argv.dup
      argv[2] = "Bug: export times out"
      run(argv)
      expect(a_request(:post, "https://api.trello.com/1/cards")).not_to have_been_made
    end

    it "exits 1 for a blank required field" do
      argv = ["bug", "new", "Export times out", "--steps", "Open Reports",
              "--expected", "   ", "--actual", "Spinner hangs."]
      expect(run(argv)).to eq(1)
    end

    it "exits 1 for a missing required field" do
      argv = ["bug", "new", "Export times out", "--steps", "Open Reports",
              "--expected", "CSV downloads."]
      expect(run(argv)).to eq(1)
    end

    it "exits 1 for a feature with no gherkin" do
      argv = ["feature", "new", "Filter the queue", "--what", "Filter", "--why", "Speed",
              "--done-when", "The filter works"]
      expect(run(argv)).to eq(1)
    end

    it "creates no card for a feature with no gherkin" do
      argv = ["feature", "new", "Filter the queue", "--what", "Filter", "--why", "Speed",
              "--done-when", "The filter works"]
      run(argv)
      expect(a_request(:post, "https://api.trello.com/1/cards")).not_to have_been_made
    end
  end
end
