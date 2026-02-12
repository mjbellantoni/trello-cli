# Trello CLI

A command-line interface for managing Trello cards, checklists, comments, and attachments.

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

Create a `.trello.yml` file in your project root:

```yaml
board_id: "YOUR_BOARD_ID"
default_list: "Inbox"
```

Set environment variables for authentication:

```bash
export TRELLO_API_KEY="your_api_key"
export TRELLO_TOKEN="your_token"
```

## Usage

### Cards

```bash
trello card new "Task title" -d "Description" -l "List Name" -L label1 label2
trello card show #123
trello card move #123 "Done"
trello card update #123 -d "New description"
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
