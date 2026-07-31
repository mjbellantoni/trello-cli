# Card command enhancements design

Two independent additions to the `card` command, shipped together in 2.6.0.

## 1. `card move --position`

### Context

`trello card move REF LIST` moves a card to a different list but always drops
it at Trello's default position. Users want to control placement (e.g. move a
card to the top of the target list).

### Behavior

- New option: `card move REF LIST --position VALUE` (`-p`).
- `VALUE` accepts `top`, `bottom`, or a number (e.g. `1`, `65535.5`).
- Invalid values error out with a clear message and exit 1 — no silent
  pass-through to the API.
- Omitting `--position` keeps today's behavior exactly.

### Implementation

- **API** `TrelloCli::Api::Card.move(client, config, card_ref, list_name, position: nil)`
  - Builds `{ idList: ... }`; when `position` is given, validates and adds
    `pos:`.
  - `top`/`bottom` pass through as strings; numeric strings convert to Float.
  - Invalid input raises `TrelloCli::Error` (rescued by the CLI). This keeps
    validation testable at the API layer, where the existing specs live (there
    is no CLI spec layer).
- **CLI** `cli/card.rb` `move`: add `option :position, type: :string, aliases: "-p"`
  and forward it to `Card.move`.

### Testing

Extend `spec/trello_cli/api/card_spec.rb` with a `.move` describe block:
- moves to a list without a position (existing behavior, body has only idList)
- `--position top` / `bottom` send `pos` as the string
- numeric position sends `pos` as a float
- invalid position raises `TrelloCli::Error`

## 2. `card update --title`

### Context

`card update` could only change the description (`-d`). There was no way to
rename a card. (The original request was framed as adding `--description`, but
that already existed — the real gap was the title.) Trello stores the title in
the `name` field.

### Behavior

- New option: `card update REF --title VALUE` (`-t`), maps to Trello `name`.
- `--description` and `--title` are both optional; at least one is required or
  the command errors with exit 1.
- Either or both may be given in a single call.

### Implementation

- **API** `TrelloCli::Api::Card.update(client, config, card_ref, description: nil, name: nil)`
  - Both keywords now optional; builds a body with only the provided fields.
- **CLI** `cli/card.rb` `update`: add `option :title` (`-t`), require at least
  one field, and report which fields were updated.

### Testing

Extend the `.update` describe block in `spec/trello_cli/api/card_spec.rb`:
- updates the description (existing behavior)
- updates the title (`name` in body)
- updates both in one request
