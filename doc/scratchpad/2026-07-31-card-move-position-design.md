# `card move --position` design

## Context

`trello card move REF LIST` moves a card to a different list but always drops
it at Trello's default position. Users want to control placement (e.g. move a
card to the top of the target list).

Note: `card update --description` was also requested but already exists
(`cli/card.rb`, `api/card.rb`, README, and the shipped gem). The reason agents
report it "unavailable" is that the `trello-cli` *plugin skills* never document
`card update` — a gap in the separate `mjb-plugins/trello-cli` repo, out of
scope here. Only `card move --position` is implemented in this change.

## Behavior

- New option: `card move REF LIST --position VALUE` (`-p`).
- `VALUE` accepts `top`, `bottom`, or a number (e.g. `1`, `65535.5`).
- Invalid values error out with a clear message and exit 1 — no silent
  pass-through to the API.
- Omitting `--position` keeps today's behavior exactly.

## Implementation

- **API** `TrelloCli::Api::Card.move(client, config, card_ref, list_name, position: nil)`
  - Builds `{ idList: ... }`; when `position` is given, validates and adds
    `pos:`.
  - `top`/`bottom` pass through as strings; numeric strings convert to Float.
  - Invalid input raises `TrelloCli::Error` (rescued by the CLI). This keeps
    validation testable at the API layer, where the existing specs live (there
    is no CLI spec layer).
- **CLI** `cli/card.rb` `move`: add `option :position, type: :string, aliases: "-p"`
  and forward it to `Card.move`.

## Testing

Extend `spec/trello_cli/api/card_spec.rb` with a `.move` describe block:
- moves to a list without a position (existing behavior, body has only idList)
- `--position top` / `bottom` send `pos` as the string
- numeric position sends `pos` as a float
- invalid position raises `TrelloCli::Error`
