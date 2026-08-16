# frozen_string_literal: true

class TrelloCli::Api::Member
  def self.all(client, config)
    client.get("/boards/#{config.board_id}/members", { fields: "id,username,fullName,initials" })
  end

  # Callers name a person however they know them. Username is tried first
  # because Trello guarantees it is unique — a full name or a set of initials
  # can collide, and either can equal somebody else's username.
  #
  # Exact matches are exhausted before any prefix match, so a person whose
  # whole name is another person's prefix is never shadowed by them.
  def self.find_by_name(client, config, name)
    members = all(client, config)
    wanted = normalize(name)

    exact = members.find { |m| normalize(m["username"]) == wanted } ||
            members.find { |m| normalize(m["fullName"]) == wanted } ||
            members.find { |m| normalize(m["initials"]) == wanted }
    return exact if exact

    # Real usernames carry noise nobody types from memory — collinstewart12,
    # matthew_rl — so the obvious guess has to land.
    prefixed = members.select do |m|
      normalize(m["username"]).start_with?(wanted) || normalize(m["fullName"]).start_with?(wanted)
    end

    return prefixed.first if prefixed.one?
    raise TrelloCli::Error, ambiguous_message(name, prefixed) if prefixed.size > 1

    raise TrelloCli::NotFoundError, not_found_message(name, members)
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

    "Member not found: #{name}\nBoard members:\n#{roster_lines(members).join("\n")}"
  end

  # Naming two people equally well is not a match. Say who was meant and let
  # the caller pick rather than assigning the card to a coin flip.
  def self.ambiguous_message(name, members)
    "Member is ambiguous: #{name}\nMatches:\n#{roster_lines(members).join("\n")}"
  end

  def self.roster_lines(members)
    width = members.map { |m| m["username"].to_s.length }.max
    members.map { |m| "  #{m['username'].to_s.ljust(width)} #{m['fullName']}".rstrip }
  end

  private_class_method :normalize, :not_found_message, :ambiguous_message, :roster_lines
end
