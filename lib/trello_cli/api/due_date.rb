# frozen_string_literal: true

require "date"
require "time"

# Translates due date input into the ISO 8601 UTC string the Trello API expects.
# Bare dates and relative forms land at noon local time, which is where Trello's
# own date picker puts them. `none` returns nil, which clears the date.
class TrelloCli::Api::DueDate
  NOON = 12
  CLEAR = "none"
  KEYWORD_DAYS = { "today" => 0, "tomorrow" => 1 }.freeze
  DAYS_PER_UNIT = { "d" => 1, "w" => 7 }.freeze

  OFFSET = /\A\+(\d+)([dw])\z/i
  DATE = /\A\d{4}-\d{2}-\d{2}\z/
  DATE_TIME = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(Z|[+-]\d{2}:\d{2})?\z/i

  ACCEPTED = "expected YYYY-MM-DD, YYYY-MM-DDTHH:MM, today, tomorrow, +Nd, +Nw, or none"

  def self.parse(value, now: Time.now)
    text = value.to_s.strip
    return nil if text.downcase == CLEAR

    time = resolve(text, now)
    raise TrelloCli::Error, "Invalid due date: #{value} (#{ACCEPTED})" if time.nil?

    time.getutc.iso8601
  end

  # Returns nil for anything the grammar does not cover, so parse owns the one
  # error message.
  def self.resolve(text, now)
    days = days_ahead(text)
    return noon(now.to_date + days) unless days.nil?

    return noon(Date.iso8601(text)) if text.match?(DATE)
    return Time.parse(text) if text.match?(DATE_TIME)

    nil
  rescue ArgumentError, Date::Error
    nil
  end

  def self.days_ahead(text)
    key = text.downcase
    return KEYWORD_DAYS[key] if KEYWORD_DAYS.key?(key)

    match = OFFSET.match(key)
    match && match[1].to_i * DAYS_PER_UNIT.fetch(match[2])
  end

  # Date arithmetic rather than adding seconds, so a DST boundary between now
  # and the target day cannot shift the result onto the wrong date.
  def self.noon(date)
    Time.new(date.year, date.month, date.day, NOON, 0, 0)
  end
end
