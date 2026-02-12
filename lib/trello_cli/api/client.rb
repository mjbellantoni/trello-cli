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
