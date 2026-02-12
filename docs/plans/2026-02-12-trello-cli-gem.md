# Trello CLI Gem Extraction Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the Trello CLI from enki into a standalone Ruby gem that can be installed in other projects via binstub.

**Architecture:** Standard Ruby gem structure with Thor-based CLI. The gem provides both a library (`TrelloCli`) and an executable (`trello`). Configuration remains file-based (`.trello.yml`) with environment variables for credentials.

**Tech Stack:** Ruby, Thor (CLI framework), Bundler (gem structure), RSpec (testing), WebMock (API mocking)

---

## Task 1: Initialize Gem Structure

**Files:**
- Create: `trello-cli.gemspec`
- Create: `Gemfile`
- Create: `lib/trello_cli.rb`
- Create: `lib/trello_cli/version.rb`

**Step 1: Create the gemspec**

```ruby
# trello-cli.gemspec
# frozen_string_literal: true

require_relative "lib/trello_cli/version"

Gem::Specification.new do |spec|
  spec.name = "trello-cli"
  spec.version = TrelloCli::VERSION
  spec.authors = ["MJB"]
  spec.summary = "CLI for Trello API"
  spec.description = "A command-line interface for managing Trello cards, checklists, comments, and attachments"
  spec.homepage = "https://github.com/mjb/trello-cli"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["trello"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.0"

  spec.metadata["rubygems_mfa_required"] = "true"
end
```

**Step 2: Create the Gemfile**

```ruby
# Gemfile
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rspec", "~> 3.0"
  gem "webmock", "~> 3.0"
end
```

**Step 3: Create version file**

```ruby
# lib/trello_cli/version.rb
# frozen_string_literal: true

module TrelloCli
  VERSION = "0.1.0"
end
```

**Step 4: Create main library entry point**

```ruby
# lib/trello_cli.rb
# frozen_string_literal: true

require_relative "trello_cli/version"

module TrelloCli
  class Error < StandardError; end
  class ConfigError < Error; end
  class NotFoundError < Error; end
  class AuthError < Error; end
end

require_relative "trello_cli/api"
require_relative "trello_cli/api/config"
require_relative "trello_cli/api/client"
require_relative "trello_cli/api/card_ref"
require_relative "trello_cli/api/list"
require_relative "trello_cli/api/card"
require_relative "trello_cli/api/attachment"
require_relative "trello_cli/api/comment"
require_relative "trello_cli/api/checklist"
```

**Step 5: Run bundle install**

Run: `bundle install`
Expected: Bundler resolves dependencies and creates Gemfile.lock

**Step 6: Commit**

```bash
git init
git add trello-cli.gemspec Gemfile lib/trello_cli.rb lib/trello_cli/version.rb
git commit -m "feat: initialize gem structure with gemspec and entry point"
```

---

## Task 2: Create API Module and Config

**Files:**
- Create: `lib/trello_cli/api.rb`
- Create: `lib/trello_cli/api/config.rb`

**Step 1: Create API namespace module**

```ruby
# lib/trello_cli/api.rb
# frozen_string_literal: true

module TrelloCli::Api
end
```

**Step 2: Create Config class**

```ruby
# lib/trello_cli/api/config.rb
# frozen_string_literal: true

require "yaml"

class TrelloCli::Api::Config
  attr_reader :board_id
  attr_reader :default_list
  attr_reader :api_key
  attr_reader :token

  def self.load
    new
  end

  def initialize
    load_file_config
    load_env_config
  end

  private

  def load_file_config
    config_path = config_file_path
    unless File.exist?(config_path)
      raise TrelloCli::ConfigError, ".trello.yml not found at #{config_path}"
    end

    yaml = YAML.load_file(config_path)
    @board_id = yaml["board_id"]
    @default_list = yaml["default_list"]
  end

  def load_env_config
    @api_key = fetch_env("TRELLO_API_KEY")
    @token = fetch_env("TRELLO_TOKEN")
  end

  def fetch_env(key)
    ENV.fetch(key)
  rescue KeyError
    raise TrelloCli::ConfigError, "#{key} not set"
  end

  def config_file_path
    File.join(Dir.pwd, ".trello.yml")
  end
end
```

**Step 3: Commit**

```bash
git add lib/trello_cli/api.rb lib/trello_cli/api/config.rb
git commit -m "feat: add API module and Config class"
```

---

## Task 3: Create API Client

**Files:**
- Create: `lib/trello_cli/api/client.rb`

**Step 1: Create Client class**

```ruby
# lib/trello_cli/api/client.rb
# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "securerandom"

class TrelloCli::Api::Client
  BASE_URL = "https://api.trello.com/1"

  def initialize(config)
    @config = config
  end

  def get(path, params = {})
    uri = build_uri(path, params)
    request = Net::HTTP::Get.new(uri)
    execute(uri, request)
  end

  def post(path, body = {})
    uri = build_uri(path)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json
    execute(uri, request)
  end

  def put(path, body = {})
    uri = build_uri(path)
    request = Net::HTTP::Put.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json
    execute(uri, request)
  end

  def delete(path)
    uri = build_uri(path)
    request = Net::HTTP::Delete.new(uri)
    execute(uri, request)
  end

  def post_multipart(path, file:, name:)
    uri = build_uri(path)

    boundary = "----RubyFormBoundary#{SecureRandom.hex(8)}"

    file_content = File.binread(file)
    mime_type = mime_type_for(file)

    body = []
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{name}\"\r\n"
    body << "Content-Type: #{mime_type}\r\n\r\n"
    body << file_content
    body << "\r\n--#{boundary}--\r\n"

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
    request.body = body.join

    execute(uri, request)
  end

  private

  attr_reader :config

  def build_uri(path, extra_params = {})
    uri = URI("#{BASE_URL}#{path}")
    params = { key: config.api_key, token: config.token }.merge(extra_params)
    uri.query = URI.encode_www_form(params)
    uri
  end

  def execute(uri, request)
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    handle_response(response)
  end

  def handle_response(response)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body)
    when 401
      raise TrelloCli::AuthError, "Authentication failed: #{response.body}"
    when 404
      raise TrelloCli::NotFoundError, "Resource not found: #{response.body}"
    else
      raise TrelloCli::Error, "API error (#{response.code}): #{response.body}"
    end
  end

  def mime_type_for(file_path)
    case File.extname(file_path).downcase
    when ".png" then "image/png"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".gif" then "image/gif"
    when ".pdf" then "application/pdf"
    when ".txt" then "text/plain"
    else "application/octet-stream"
    end
  end
end
```

**Step 2: Commit**

```bash
git add lib/trello_cli/api/client.rb
git commit -m "feat: add API Client with HTTP methods"
```

---

## Task 4: Create API Model Classes

**Files:**
- Create: `lib/trello_cli/api/card_ref.rb`
- Create: `lib/trello_cli/api/list.rb`
- Create: `lib/trello_cli/api/card.rb`
- Create: `lib/trello_cli/api/attachment.rb`
- Create: `lib/trello_cli/api/comment.rb`
- Create: `lib/trello_cli/api/checklist.rb`

**Step 1: Create CardRef class**

```ruby
# lib/trello_cli/api/card_ref.rb
# frozen_string_literal: true

class TrelloCli::Api::CardRef
  attr_reader :short_link
  attr_reader :card_number

  TRELLO_URL_PATTERN = %r{trello\.com/c/([a-zA-Z0-9]+)}.freeze
  CARD_NUMBER_PATTERN = /\A#?(\d+)\z/.freeze

  def self.parse(input)
    new(input)
  end

  def initialize(input)
    @input = input.to_s.strip
    raise ArgumentError, "Card reference cannot be empty" if @input.empty?

    parse_input
  end

  def to_api_id(client, config)
    if short_link
      short_link
    elsif card_number
      card = client.get("/boards/#{config.board_id}/cards/#{card_number}")
      card["id"]
    end
  end

  private

  def parse_input
    if (match = @input.match(TRELLO_URL_PATTERN))
      @short_link = match[1]
    elsif (match = @input.match(CARD_NUMBER_PATTERN))
      @card_number = match[1].to_i
    else
      @short_link = @input
    end
  end
end
```

**Step 2: Create List class**

```ruby
# lib/trello_cli/api/list.rb
# frozen_string_literal: true

class TrelloCli::Api::List
  def self.find_by_name(client, config, name)
    lists = client.get("/boards/#{config.board_id}/lists")
    list = lists.find { |l| l["name"] == name }
    raise TrelloCli::NotFoundError, "List not found: #{name}" unless list

    list
  end

  def self.all(client, config)
    client.get("/boards/#{config.board_id}/lists")
  end
end
```

**Step 3: Create Card class**

```ruby
# lib/trello_cli/api/card.rb
# frozen_string_literal: true

class TrelloCli::Api::Card
  def self.find(client, config, card_ref)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    client.get("/cards/#{card_id}", { checklists: "all", attachments: "true", actions: "commentCard" })
  end

  def self.create(client, config, title:, description: nil, list: nil, labels: [], position: nil)
    list_name = list || config.default_list
    list_data = TrelloCli::Api::List.find_by_name(client, config, list_name)

    body = {
      name: title,
      idList: list_data["id"],
      idBoard: config.board_id
    }
    body[:desc] = description if description
    body[:idLabels] = resolve_labels(client, config, labels).join(",") if labels.any?
    body[:pos] = position if position

    client.post("/cards", body)
  end

  def self.move(client, config, card_ref, list_name)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    list_data = TrelloCli::Api::List.find_by_name(client, config, list_name)
    client.put("/cards/#{card_id}", { idList: list_data["id"] })
  end

  def self.update(client, config, card_ref, description:)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    client.put("/cards/#{card_id}", { desc: description })
  end

  def self.resolve_labels(client, config, label_names)
    board_labels = client.get("/boards/#{config.board_id}/labels")
    label_names.map do |name|
      label = board_labels.find { |l| l["name"].downcase == name.downcase }
      raise TrelloCli::NotFoundError, "Label not found: #{name}" unless label

      label["id"]
    end
  end
end
```

**Step 4: Create Attachment class**

```ruby
# lib/trello_cli/api/attachment.rb
# frozen_string_literal: true

class TrelloCli::Api::Attachment
  def self.list(client, card_id)
    client.get("/cards/#{card_id}/attachments")
  end

  def self.download_url(client, card_id, attachment_id)
    attachment = client.get("/cards/#{card_id}/attachments/#{attachment_id}")
    attachment["url"]
  end

  def self.find_by_name(client, card_id, filename)
    attachments = list(client, card_id)
    attachment = attachments.find { |a| a["name"] == filename }
    raise TrelloCli::NotFoundError, "Attachment not found: #{filename}" unless attachment

    attachment
  end

  def self.upload(client, card_id, file_path)
    name = File.basename(file_path)
    client.post_multipart("/cards/#{card_id}/attachments", file: file_path, name: name)
  end
end
```

**Step 5: Create Comment class**

```ruby
# lib/trello_cli/api/comment.rb
# frozen_string_literal: true

class TrelloCli::Api::Comment
  def self.list(client, card_id)
    client.get("/cards/#{card_id}/actions", { filter: "commentCard" })
  end

  def self.add(client, card_id, text)
    raise ArgumentError, "Comment text cannot be empty" if text.nil? || text.strip.empty?

    client.post("/cards/#{card_id}/actions/comments", { text: text })
  end
end
```

**Step 6: Create Checklist class**

```ruby
# lib/trello_cli/api/checklist.rb
# frozen_string_literal: true

class TrelloCli::Api::Checklist
  def self.add(client, card_id, name)
    raise ArgumentError, "Checklist name cannot be blank" if name.nil? || name.strip.empty?

    client.post("/cards/#{card_id}/checklists", { name: name })
  end

  def self.remove(client, checklist_id)
    client.delete("/checklists/#{checklist_id}")
  end

  def self.rename(client, checklist_id, name)
    raise ArgumentError, "Checklist name cannot be blank" if name.nil? || name.strip.empty?

    client.put("/checklists/#{checklist_id}", { name: name })
  end

  def self.find_by_name(client, card_id, name)
    card = client.get("/cards/#{card_id}", { checklists: "all" })
    checklists = (card["checklists"] || []).select { |cl| cl["name"] == name }

    raise TrelloCli::NotFoundError, "Checklist not found: #{name}" if checklists.empty?
    raise TrelloCli::Error, "Multiple checklists named '#{name}' on this card" if checklists.size > 1

    checklists.first
  end

  def self.add_item(client, checklist_id, name)
    raise ArgumentError, "Item name cannot be blank" if name.nil? || name.strip.empty?

    client.post("/checklists/#{checklist_id}/checkItems", { name: name })
  end

  def self.update_item(client, card_id, item_id, attrs)
    client.put("/cards/#{card_id}/checkItem/#{item_id}", attrs)
  end

  def self.remove_item(client, checklist_id, item_id)
    client.delete("/checklists/#{checklist_id}/checkItems/#{item_id}")
  end

  def self.find_item(checklist, item_ref)
    items = (checklist["checkItems"] || []).sort_by { |i| i["pos"] || 0 }

    if item_ref.match?(/\A\d+\z/)
      pos = item_ref.to_i
      raise ArgumentError, "Position #{pos} is out of range (1-#{items.size})" if pos < 1 || pos > items.size

      items[pos - 1]
    else
      item = items.find { |i| i["name"] == item_ref }
      raise TrelloCli::NotFoundError, "Item not found: #{item_ref}" unless item

      item
    end
  end
end
```

**Step 7: Commit**

```bash
git add lib/trello_cli/api/
git commit -m "feat: add API model classes (CardRef, List, Card, Attachment, Comment, Checklist)"
```

---

## Task 5: Create CLI Classes

**Files:**
- Create: `lib/trello_cli/cli.rb`
- Create: `lib/trello_cli/cli/card.rb`
- Create: `lib/trello_cli/cli/attach.rb`
- Create: `lib/trello_cli/cli/comment.rb`
- Create: `lib/trello_cli/cli/checklist.rb`

**Step 1: Create main CLI class**

```ruby
# lib/trello_cli/cli.rb
# frozen_string_literal: true

require "thor"
require_relative "../trello_cli"

class TrelloCli::Cli < Thor
  def self.exit_on_failure?
    true
  end
end

require_relative "cli/card"
require_relative "cli/attach"
require_relative "cli/comment"
require_relative "cli/checklist"

class TrelloCli::Cli < Thor
  desc "card SUBCOMMAND", "Manage Trello cards"
  subcommand "card", TrelloCli::Cli::Card

  desc "attach SUBCOMMAND", "Manage card attachments"
  subcommand "attach", TrelloCli::Cli::Attach

  desc "comment SUBCOMMAND", "Manage card comments"
  subcommand "comment", TrelloCli::Cli::Comment

  desc "checklist SUBCOMMAND", "Manage card checklists"
  subcommand "checklist", TrelloCli::Cli::Checklist
end
```

**Step 2: Create Card CLI subcommand**

```ruby
# lib/trello_cli/cli/card.rb
# frozen_string_literal: true

class TrelloCli::Cli::Card < Thor
  def self.exit_on_failure?
    true
  end

  desc "new TITLE", "Create a new card"
  option :description, type: :string, aliases: "-d", desc: "Card description (markdown)"
  option :list, type: :string, aliases: "-l", desc: "List name (defaults to config default_list)"
  option :label, type: :array, aliases: "-L", default: [], desc: "Labels to add (repeatable)"
  option :position, type: :string, aliases: "-p", enum: %w[top bottom], desc: "Position in list (top or bottom)"
  def new(title)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card = TrelloCli::Api::Card.create(
      client,
      config,
      title: title,
      description: options[:description],
      list: options[:list],
      labels: options[:label],
      position: options[:position]
    )

    say "Created: #{card['shortUrl']}", :green
    say "Card ##{card['idShort']}: #{card['name']}" if card["idShort"]
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "show REF", "Show card details"
  def show(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card = TrelloCli::Api::Card.find(client, config, ref)

    say card["name"], :bold
    say "URL: #{card['shortUrl']}"
    say ""

    if card["labels"]&.any?
      labels = card["labels"].map { |l| l["name"] }.join(", ")
      say "Labels: #{labels}"
    end

    if card["desc"] && !card["desc"].empty?
      say ""
      say "Description:"
      say card["desc"]
    end

    if card["checklists"]&.any?
      say ""
      say "Checklists:"
      card["checklists"].each do |checklist|
        items = checklist["checkItems"] || []
        completed = items.count { |i| i["state"] == "complete" }
        total = items.size
        progress = total.positive? ? "(#{completed}/#{total})" : ""
        say "  #{checklist['name']}: #{progress}"
        items.sort_by { |i| i["pos"] || 0 }.each do |item|
          status = item["state"] == "complete" ? "[x]" : "[ ]"
          say "    #{status} #{item['name']}"
        end
      end
    end

    if card["attachments"]&.any?
      say ""
      say "Attachments:"
      card["attachments"].each do |att|
        say "  - #{att['name']}"
      end
    end

    if card["actions"]&.any?
      say ""
      say "Comments (#{[card['actions'].length, 3].min} most recent):"
      card["actions"].first(3).each do |comment|
        date = Time.parse(comment["date"]).strftime("%b %d")
        text = comment.dig("data", "text") || ""
        truncated = text.length > 80 ? "#{text[0, 77]}..." : text
        truncated = truncated.gsub(/\s+/, " ")
        say "  #{date}: #{truncated}"
      end
    end
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "move REF LIST", "Move a card to a different list"
  def move(ref, list_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Card.move(client, config, ref, list_name)

    say "Moved to: #{list_name}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "update REF", "Update card fields"
  option :description, type: :string, aliases: "-d", desc: "New description (markdown)"
  def update(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    if options[:description].nil?
      say "Error: No update options provided. Use --description to update.", :red
      exit 1
    end

    TrelloCli::Api::Card.update(client, config, ref, description: options[:description])

    say "Updated card description", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
```

**Step 3: Create Attach CLI subcommand**

```ruby
# lib/trello_cli/cli/attach.rb
# frozen_string_literal: true

require "open-uri"

class TrelloCli::Cli::Attach < Thor
  def self.exit_on_failure?
    true
  end

  desc "list REF", "List attachments on a card"
  def list(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)
    attachments = TrelloCli::Api::Attachment.list(client, card_id)

    if attachments.empty?
      say "No attachments"
      return
    end

    attachments.each do |att|
      say att["name"]
      say "  URL: #{att['url']}"
      say ""
    end
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "get REF FILENAME", "Download an attachment"
  option :output, type: :string, aliases: "-o", desc: "Output path (defaults to current directory)"
  def get(ref, filename)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    attachment = TrelloCli::Api::Attachment.find_by_name(client, card_id, filename)
    url = attachment["url"]

    output_path = options[:output] || File.join(Dir.pwd, filename)

    say "Downloading #{filename}..."

    download_url = "#{url}?key=#{config.api_key}&token=#{config.token}"

    URI.parse(download_url).open do |remote|
      File.binwrite(output_path, remote.read)
    end

    say "Saved to: #{output_path}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  rescue OpenURI::HTTPError => e
    say "Download failed: #{e.message}", :red
    exit 1
  end

  desc "upload REF FILE", "Upload a file as attachment"
  def upload(ref, file_path)
    unless File.exist?(file_path)
      say "Error: File not found: #{file_path}", :red
      exit 1
    end

    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    attachment = TrelloCli::Api::Attachment.upload(client, card_id, file_path)

    say "Uploaded: #{attachment['name']}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
```

**Step 4: Create Comment CLI subcommand**

```ruby
# lib/trello_cli/cli/comment.rb
# frozen_string_literal: true

class TrelloCli::Cli::Comment < Thor
  def self.exit_on_failure?
    true
  end

  desc "list REF", "List comments on a card"
  def list(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)
    comments = TrelloCli::Api::Comment.list(client, card_id)

    if comments.empty?
      say "No comments"
      return
    end

    comments.each do |comment|
      date = Time.parse(comment["date"]).strftime("%b %d, %Y %H:%M")
      author = comment.dig("memberCreator", "fullName") || "Unknown"
      text = comment.dig("data", "text") || ""

      say "--- #{date} | #{author} ---"
      say text
      say ""
    end
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "add REF TEXT", "Add a comment to a card"
  def add(ref, text)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    TrelloCli::Api::Comment.add(client, card_id, text)

    say "Comment added", :green
  rescue ArgumentError => e
    say "Error: #{e.message}", :red
    exit 1
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
```

**Step 5: Create Checklist CLI subcommand**

```ruby
# lib/trello_cli/cli/checklist.rb
# frozen_string_literal: true

class TrelloCli::Cli::Checklist < Thor
  def self.exit_on_failure?
    true
  end

  desc "add REF NAME", "Add a checklist to a card"
  def add(ref, name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    TrelloCli::Api::Checklist.add(client, card_id, name)

    say "Checklist added: #{name}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "remove REF NAME", "Remove a checklist from a card"
  def remove(ref, name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, name)
    TrelloCli::Api::Checklist.remove(client, checklist["id"])

    say "Checklist removed: #{name}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "rename REF NAME NEW_NAME", "Rename a checklist"
  def rename(ref, name, new_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, name)
    TrelloCli::Api::Checklist.rename(client, checklist["id"], new_name)

    say "Checklist renamed: #{name} -> #{new_name}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-add REF CHECKLIST ITEM", "Add an item to a checklist"
  map "item-add" => :item_add
  def item_add(ref, checklist_name, item_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    TrelloCli::Api::Checklist.add_item(client, checklist["id"], item_name)

    say "Item added: #{item_name}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-edit REF CHECKLIST ITEM NEW_TEXT", "Edit a checklist item"
  map "item-edit" => :item_edit
  def item_edit(ref, checklist_name, item_ref, new_text)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    item = TrelloCli::Api::Checklist.find_item(checklist, item_ref)
    TrelloCli::Api::Checklist.update_item(client, card_id, item["id"], name: new_text)

    say "Item updated: #{new_text}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-check REF CHECKLIST ITEM", "Mark a checklist item complete"
  map "item-check" => :item_check
  def item_check(ref, checklist_name, item_ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    item = TrelloCli::Api::Checklist.find_item(checklist, item_ref)
    TrelloCli::Api::Checklist.update_item(client, card_id, item["id"], state: "complete")

    say "Item checked: #{item['name']}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-uncheck REF CHECKLIST ITEM", "Mark a checklist item incomplete"
  map "item-uncheck" => :item_uncheck
  def item_uncheck(ref, checklist_name, item_ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    item = TrelloCli::Api::Checklist.find_item(checklist, item_ref)
    TrelloCli::Api::Checklist.update_item(client, card_id, item["id"], state: "incomplete")

    say "Item unchecked: #{item['name']}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-remove REF CHECKLIST ITEM", "Remove a checklist item"
  map "item-remove" => :item_remove
  def item_remove(ref, checklist_name, item_ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    item = TrelloCli::Api::Checklist.find_item(checklist, item_ref)
    TrelloCli::Api::Checklist.remove_item(client, checklist["id"], item["id"])

    say "Item removed: #{item['name']}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
```

**Step 6: Update main entry point to include CLI**

Add to `lib/trello_cli.rb` at the end:

```ruby
require_relative "trello_cli/cli"
```

**Step 7: Commit**

```bash
git add lib/trello_cli/cli.rb lib/trello_cli/cli/
git commit -m "feat: add CLI classes with Thor subcommands"
```

---

## Task 6: Create Executable

**Files:**
- Create: `exe/trello`

**Step 1: Create executable**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "trello_cli/cli"

TrelloCli::Cli.start(ARGV)
```

**Step 2: Make executable**

Run: `chmod +x exe/trello`

**Step 3: Test executable runs**

Run: `bundle exec exe/trello help`
Expected: Shows help output with card, attach, comment, checklist subcommands

**Step 4: Commit**

```bash
git add exe/trello
git commit -m "feat: add trello executable"
```

---

## Task 7: Set Up RSpec and Write Tests

**Files:**
- Create: `.rspec`
- Create: `spec/spec_helper.rb`
- Create: `spec/trello_cli/api/client_spec.rb`
- Create: `spec/trello_cli/api/config_spec.rb`
- Create: `spec/trello_cli/api/card_ref_spec.rb`

**Step 1: Create .rspec file**

```
--require spec_helper
--format documentation
```

**Step 2: Create spec_helper.rb**

```ruby
# frozen_string_literal: true

require "trello_cli"
require "webmock/rspec"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

WebMock.disable_net_connect!(allow_localhost: true)
```

**Step 3: Create client_spec.rb**

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::Client do
  let(:config) do
    instance_double(
      TrelloCli::Api::Config,
      api_key: "test_key",
      token: "test_token",
      board_id: "test_board"
    )
  end
  let(:client) { described_class.new(config) }

  describe "#get" do
    let(:response_body) { { "id" => "123", "name" => "Test" }.to_json }

    before do
      stub_request(:get, "https://api.trello.com/1/boards/test_board")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "makes authenticated GET request" do
      result = client.get("/boards/test_board")
      expect(result).to eq({ "id" => "123", "name" => "Test" })
    end

    context "when response is 401" do
      before do
        stub_request(:get, "https://api.trello.com/1/boards/test_board")
          .with(query: { key: "test_key", token: "test_token" })
          .to_return(status: 401, body: "unauthorized")
      end

      it "raises AuthError" do
        expect { client.get("/boards/test_board") }.to raise_error(TrelloCli::AuthError)
      end
    end

    context "when response is 404" do
      before do
        stub_request(:get, "https://api.trello.com/1/boards/test_board")
          .with(query: { key: "test_key", token: "test_token" })
          .to_return(status: 404, body: "not found")
      end

      it "raises NotFoundError" do
        expect { client.get("/boards/test_board") }.to raise_error(TrelloCli::NotFoundError)
      end
    end
  end

  describe "#post" do
    let(:response_body) { { "id" => "new123" }.to_json }

    before do
      stub_request(:post, "https://api.trello.com/1/cards")
        .with(
          query: { key: "test_key", token: "test_token" },
          body: { name: "Test Card" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "makes authenticated POST request with JSON body" do
      result = client.post("/cards", { name: "Test Card" })
      expect(result).to eq({ "id" => "new123" })
    end
  end

  describe "#delete" do
    let(:response_body) { { "_value" => nil }.to_json }

    before do
      stub_request(:delete, "https://api.trello.com/1/checklists/cl123")
        .with(query: { key: "test_key", token: "test_token" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "makes authenticated DELETE request" do
      result = client.delete("/checklists/cl123")
      expect(result).to eq({ "_value" => nil })
    end
  end
end
```

**Step 4: Create card_ref_spec.rb**

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::CardRef do
  describe ".parse" do
    it "parses Trello URL" do
      ref = described_class.parse("https://trello.com/c/abc123/card-name")
      expect(ref.short_link).to eq("abc123")
      expect(ref.card_number).to be_nil
    end

    it "parses card number with hash" do
      ref = described_class.parse("#42")
      expect(ref.card_number).to eq(42)
      expect(ref.short_link).to be_nil
    end

    it "parses card number without hash" do
      ref = described_class.parse("42")
      expect(ref.card_number).to eq(42)
      expect(ref.short_link).to be_nil
    end

    it "treats unknown format as short link" do
      ref = described_class.parse("xyz789")
      expect(ref.short_link).to eq("xyz789")
      expect(ref.card_number).to be_nil
    end

    it "raises error for empty input" do
      expect { described_class.parse("") }.to raise_error(ArgumentError, /empty/)
    end
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 6: Commit**

```bash
git add .rspec spec/
git commit -m "feat: add RSpec tests for Client and CardRef"
```

---

## Task 8: Add Binstub Support for Host Projects

**Files:**
- Update: gemspec to ensure proper installation

**Step 1: Verify gem builds correctly**

Run: `gem build trello-cli.gemspec`
Expected: Creates trello-cli-0.1.0.gem file

**Step 2: Test local gem installation**

Run: `gem install ./trello-cli-0.1.0.gem`
Expected: Gem installs successfully

**Step 3: Verify executable is available**

Run: `trello help`
Expected: Shows help output

**Step 4: Document binstub usage in README (optional)**

For the home project, add to Gemfile:
```ruby
gem "trello-cli", path: "../trello-cli"
```

Then run:
```bash
bundle install
bundle binstubs trello-cli
```

This creates `bin/trello` binstub.

**Step 5: Clean up and commit**

```bash
rm trello-cli-0.1.0.gem
git add -A
git commit -m "docs: verify gem builds and installs correctly"
```

---

## Summary

The gem structure will be:

```
trello-cli/
├── Gemfile
├── trello-cli.gemspec
├── exe/
│   └── trello
├── lib/
│   ├── trello_cli.rb
│   └── trello_cli/
│       ├── version.rb
│       ├── api.rb
│       ├── api/
│       │   ├── attachment.rb
│       │   ├── card.rb
│       │   ├── card_ref.rb
│       │   ├── checklist.rb
│       │   ├── client.rb
│       │   ├── comment.rb
│       │   ├── config.rb
│       │   └── list.rb
│       ├── cli.rb
│       └── cli/
│           ├── attach.rb
│           ├── card.rb
│           ├── checklist.rb
│           └── comment.rb
└── spec/
    ├── spec_helper.rb
    └── trello_cli/
        └── api/
            ├── card_ref_spec.rb
            └── client_spec.rb
```

Key changes from original:
1. Module renamed from `Trello` to `TrelloCli` to avoid conflicts with other Trello gems
2. Config looks for `.trello.yml` in current working directory (not relative to gem)
3. Removed Rails-specific code paths
4. Removed dotenv dependency (host project handles env loading)
5. Uses `name: name` syntax instead of Ruby 3.1+ shorthand for broader compatibility
