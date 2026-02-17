# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::Config do
  describe ".load" do
    it "loads values from config file into ENV" do
      allow(File).to receive(:exist?).and_return(true)
      allow(YAML).to receive(:safe_load_file).and_return(
        "TRELLO_API_KEY" => "from-file",
        "TRELLO_TOKEN" => "tok-from-file",
        "TRELLO_BOARD_ID" => "board-from-file",
        "TRELLO_DEFAULT_LIST" => "list-from-file"
      )

      described_class.load

      expect(ENV["TRELLO_API_KEY"]).to eq("from-file")
      expect(ENV["TRELLO_TOKEN"]).to eq("tok-from-file")
      expect(ENV["TRELLO_BOARD_ID"]).to eq("board-from-file")
      expect(ENV["TRELLO_DEFAULT_LIST"]).to eq("list-from-file")
    ensure
      ENV.delete("TRELLO_API_KEY")
      ENV.delete("TRELLO_TOKEN")
      ENV.delete("TRELLO_BOARD_ID")
      ENV.delete("TRELLO_DEFAULT_LIST")
    end

    it "does not override existing env vars" do
      allow(File).to receive(:exist?).and_return(true)
      allow(YAML).to receive(:safe_load_file).and_return(
        "TRELLO_API_KEY" => "from-file"
      )

      ENV["TRELLO_API_KEY"] = "from-env"
      described_class.load

      expect(ENV["TRELLO_API_KEY"]).to eq("from-env")
    ensure
      ENV.delete("TRELLO_API_KEY")
    end

    it "returns a config instance when no config file exists" do
      allow(File).to receive(:exist?).and_return(false)

      result = described_class.load

      expect(result).to be_a(described_class)
    end

    it "checks local directory before home directory" do
      local_path = File.join(Dir.pwd, ".trello.yml")
      home_path = File.join(Dir.home, ".trello.yml")

      allow(File).to receive(:exist?).with(local_path).and_return(false)
      allow(File).to receive(:exist?).with(home_path).and_return(true)
      allow(YAML).to receive(:safe_load_file).with(home_path).and_return(
        "TRELLO_API_KEY" => "from-home"
      )

      described_class.load

      expect(ENV["TRELLO_API_KEY"]).to eq("from-home")
    ensure
      ENV.delete("TRELLO_API_KEY")
    end

    it "prefers local config file over home config file" do
      local_path = File.join(Dir.pwd, ".trello.yml")

      allow(File).to receive(:exist?).with(local_path).and_return(true)
      allow(YAML).to receive(:safe_load_file).with(local_path).and_return(
        "TRELLO_API_KEY" => "from-local"
      )

      described_class.load

      expect(ENV["TRELLO_API_KEY"]).to eq("from-local")
    ensure
      ENV.delete("TRELLO_API_KEY")
    end

    it "converts non-string values to strings" do
      allow(File).to receive(:exist?).and_return(true)
      allow(YAML).to receive(:safe_load_file).and_return(
        "TRELLO_BOARD_ID" => 12345
      )

      described_class.load

      expect(ENV["TRELLO_BOARD_ID"]).to eq("12345")
    ensure
      ENV.delete("TRELLO_BOARD_ID")
    end
  end

  describe ".fetch" do
    it "returns env var value" do
      ENV["TRELLO_TEST_KEY"] = "test-value"

      expect(described_class.fetch("TRELLO_TEST_KEY")).to eq("test-value")
    ensure
      ENV.delete("TRELLO_TEST_KEY")
    end

    it "returns default when key is not set" do
      expect(described_class.fetch("TRELLO_NONEXISTENT", "fallback")).to eq("fallback")
    end

    it "returns nil when key is not set and no default" do
      expect(described_class.fetch("TRELLO_NONEXISTENT")).to be_nil
    end
  end

  describe "accessor methods" do
    before do
      allow(File).to receive(:exist?).and_return(false)
      ENV["TRELLO_API_KEY"] = "key-1"
      ENV["TRELLO_TOKEN"] = "tok-1"
      ENV["TRELLO_BOARD_ID"] = "board-1"
      ENV["TRELLO_DEFAULT_LIST"] = "list-1"
    end

    after do
      ENV.delete("TRELLO_API_KEY")
      ENV.delete("TRELLO_TOKEN")
      ENV.delete("TRELLO_BOARD_ID")
      ENV.delete("TRELLO_DEFAULT_LIST")
    end

    it "returns api_key from ENV" do
      config = described_class.load
      expect(config.api_key).to eq("key-1")
    end

    it "returns token from ENV" do
      config = described_class.load
      expect(config.token).to eq("tok-1")
    end

    it "returns board_id from ENV" do
      config = described_class.load
      expect(config.board_id).to eq("board-1")
    end

    it "returns default_list from ENV" do
      config = described_class.load
      expect(config.default_list).to eq("list-1")
    end
  end
end
