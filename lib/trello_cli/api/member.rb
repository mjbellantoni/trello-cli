# frozen_string_literal: true

class TrelloCli::Api::Member
  def self.all(client, config)
    client.get("/boards/#{config.board_id}/members", { fields: "id,username,fullName,initials" })
  end

  # Callers name a person however they know them. Username is tried first
  # because Trello guarantees it is unique — a full name or a set of initials
  # can collide, and either can equal somebody else's username.
  def self.find_by_name(client, config, name)
    members = all(client, config)
    wanted = normalize(name)

    member = members.find { |m| normalize(m["username"]) == wanted } ||
             members.find { |m| normalize(m["fullName"]) == wanted } ||
             members.find { |m| normalize(m["initials"]) == wanted }

    raise TrelloCli::NotFoundError, not_found_message(name, members) unless member

    member
  end

  # What to call someone in a listing. Trello allows a blank full name, and a
  # card showing an empty Members entry would be worse than showing a handle.
  def self.display_name(member)
    full_name = member["fullName"].to_s
    full_name.empty? ? member["username"].to_s : full_name
  end

  # As display_name, but disambiguated with the handle — for confirming an
  # action, where the caller needs to see which account it actually hit.
  def self.describe(member)
    full_name = member["fullName"].to_s
    return member["username"].to_s if full_name.empty?

    "#{full_name} (#{member['username']})"
  end

  def self.normalize(value)
    value.to_s.dup.force_encoding("UTF-8").downcase
  end

  # A caller that guessed wrong needs the roster to guess right, and no other
  # command prints it.
  def self.not_found_message(name, members)
    return "Member not found: #{name}\nBoard members: (none)" if members.empty?

    width = members.map { |m| m["username"].to_s.length }.max
    roster = members.map { |m| "  #{m['username'].to_s.ljust(width)} #{m['fullName']}".rstrip }
    "Member not found: #{name}\nBoard members:\n#{roster.join("\n")}"
  end

  private_class_method :normalize, :not_found_message
end
