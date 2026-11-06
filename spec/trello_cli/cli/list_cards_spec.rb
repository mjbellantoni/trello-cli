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

  describe "reading cards in detail" do
    let(:detail_query) do
      auth.merge(fields: "idShort,name,desc,due,dueComplete,labels,shortUrl,idList,pos",
                 checklists: "all", members: "true", member_fields: "fullName,username",
                 attachments: "true", attachment_fields: "name,url")
    end

    let(:detailed) do
      [{ "idShort" => 7, "name" => "Fix login", "idList" => "l1", "pos" => 1, "shortUrl" => "u7",
         "desc" => "Broken on Safari", "labels" => [{ "name" => "Bug" }] },
       { "idShort" => 9, "name" => "Ship it", "idList" => "l2", "pos" => 1, "shortUrl" => "u9",
         "desc" => "", "labels" => [] }]
    end

    def stub_detail(path, cards)
      stub_request(:get, "https://api.trello.com/1#{path}")
        .with(query: detail_query)
        .to_return(json_response(cards))
    end

    it "prints the named list's cards as a JSON array with --json" do
      stub_detail("/lists/l1/cards", [detailed.first])

      output, status = run("Doing", "--json")

      expect(status).to eq(0)
      expect(JSON.parse(output)).to match([include("number" => 7, "list" => "Doing", "description" => "Broken on Safari",
                                                   "labels" => ["Bug"])])
    end

    it "prints every card on the board with --all --json" do
      stub_detail("/boards/test_board/cards", detailed)

      output, = run("--all", "--json")

      expect(JSON.parse(output).map { |c| [c["number"], c["list"]] }).to eq([[7, "Doing"], [9, "Done"]])
    end

    it "prints every card on the board as lines with --all alone" do
      stub_detail("/boards/test_board/cards", detailed)

      expect(run("--all")).to eq(["#7 Fix login\n#9 Ship it\n", 0])
    end

    it "applies the label filters before printing JSON" do
      stub_detail("/boards/test_board/cards", detailed)

      output, = run("--all", "--json", "--without-label", "bug")

      expect(JSON.parse(output).map { |c| c["number"] }).to eq([9])
    end

    it "prints an empty array when no card matches" do
      stub_detail("/lists/l1/cards", [])

      expect(run("Doing", "--json")).to eq(["[]\n", 0])
    end

    it "refuses a list name together with --all" do
      output, status = run("Doing", "--all")

      expect(output).to include("Error: give a list NAME or --all, not both")
      expect(status).to eq(1)
    end

    it "asks for a list name or --all when given neither" do
      output, status = run

      expect(output).to include("Error: give a list NAME or --all")
      expect(status).to eq(1)
    end

    # --format picks among plain-text layouts; JSON has only one.
    it "refuses --format together with --json" do
      output, status = run("Doing", "--json", "--format", "id")

      expect(output).to include("Error: --format and --json are mutually exclusive")
      expect(status).to eq(1)
    end
  end
end
