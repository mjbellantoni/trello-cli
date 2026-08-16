# Trello CLI

A command-line interface for managing Trello cards, labels, checklists, comments, and attachments.

## Installation

Add to your Gemfile:

```ruby
gem "trello-cli", path: "../trello-cli"
```

Then run:

```bash
bundle install
bundle binstubs trello-cli
```

## Configuration

Configuration is loaded from environment variables, with optional file-based defaults. Environment variables always take precedence.

```bash
export TRELLO_API_KEY="your_api_key"
export TRELLO_TOKEN="your_token"
export TRELLO_DEFAULT_BOARD_ID="your_board_id"
export TRELLO_DEFAULT_LIST="Inbox"
```

Alternatively, create a `.trello.yml` file in your project directory or home directory (`~/.trello.yml`). The local file takes precedence over the home file. Keys in the file are ENV var names:

```yaml
TRELLO_DEFAULT_BOARD_ID: "YOUR_BOARD_ID"
TRELLO_DEFAULT_LIST: "Inbox"
TRELLO_API_KEY: "your_api_key"
TRELLO_TOKEN: "your_token"
```

## Usage

### Cards

```bash
trello card new "Task title" -d "Description" -l "List Name" -L label1 label2
trello card show #123
trello card move #123 "Done"
trello card move #123 "Done" -p top   # place at top (top, bottom, or a number)
trello card update #123 -d "New description"
trello card update #123 -t "New title"
```

`card show` reports the card's current list and assigned members, so a
`card move` or `card assign` can be verified without going to the API.

### Assigning members

```bash
trello card assign #123 collinreed        # username
trello card assign #123 "Collin Reed"     # full name
trello card assign #123 CR                # initials
trello card unassign #123 collinreed
```

A member is matched by username first, then full name, then initials, all
case-insensitively. Username wins because Trello guarantees it is unique. If
nothing matches, the error lists the board's members.

Both commands are idempotent — assigning someone already on the card, or
unassigning someone who is not, succeeds rather than failing.

### Filing cards by kind

Each command applies its label, assembles the standard headings, and puts the
card at the top of your default list. Required fields are required: the command
exits non-zero and creates nothing if one is missing or if the description is
over the word cap.

```bash
trello bug new "Export times out on large ranges" \
  --steps "Open Reports" "Pick a 90-day range" "Click Export" \
  --expected "A CSV downloads" \
  --actual "The spinner hangs and returns a 504"

trello feature new "Let reviewers filter the queue by assignee" \
  --what "A filter control on the review queue" \
  --why "Reviewers cannot find their own work on a shared board" \
  --done-when "Given a shared queue" "When I filter by my name" "Then only my cards remain"

trello chore new "Drop the unused legacy_sessions table" \
  --what "Remove the table and its model" \
  --why-now "It blocks the session-store migration next sprint" \
  --done-when "The table is gone and no code references it"
```

Word caps are 200 words for a bug and 150 for a feature or chore, counted across
the whole assembled description including headings. Over the cap, the card is
either more than one card — split it — or the detail belongs in an attachment.

There is no `--force`. To change a limit, set it in `.trello.yml`:

```yaml
TRELLO_BUG_WORD_CAP: 120
TRELLO_FEATURE_WORD_CAP: 90
TRELLO_CHORE_WORD_CAP: 90
TRELLO_BUG_LABEL: "bug"
```

### Labels

```bash
trello label list
trello label new "bug" --color red
trello label rename "bug" "defect"
trello label delete "defect"
```

Deleting a label that is still on cards is refused. Set
`TRELLO_ALLOW_LABEL_DELETE_IN_USE=true` to permit it.

### Lists

```bash
trello list all                           # one list name per line
trello list all --count                   # append each list's open card count
trello list all --format id-name          # id, name, or id-name
trello list all --format id-name --count

trello list cards "Doing"
trello list cards "Doing" --format id
trello list cards "Doing" --format name
trello list cards "Doing" --format id-name
trello list cards "Doing" --with-label "Bug"
trello list cards "Doing" --without-label "Bug"
trello list cards "Doing" --with-label "Bug" --format id
```

### Attachments

```bash
trello attach list #123
trello attach upload #123 ./file.pdf
trello attach get #123 file.pdf -o ./downloads/
```

### Comments

```bash
trello comment list #123
trello comment add #123 "Comment text"
```

### Checklists

```bash
trello checklist add #123 "My Checklist"
trello checklist remove #123 "My Checklist"
trello checklist rename #123 "Old Name" "New Name"

trello checklist item-add #123 "My Checklist" "Task item"
trello checklist item-check #123 "My Checklist" 1
trello checklist item-uncheck #123 "My Checklist" 1
trello checklist item-edit #123 "My Checklist" 1 "Updated text"
trello checklist item-remove #123 "My Checklist" 1
```

## Card References

Cards can be referenced by:
- Card number: `#123` or `123`
- Short link: `abc123`
- Full URL: `https://trello.com/c/abc123/card-name`

## License

MIT
