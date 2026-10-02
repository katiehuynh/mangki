# mangki

mangki is a SwiftUI flashcard app for iPhone inspired by Anki, built around spaced repetition and review analytics. It helps you create, study, and maintain decks with FSRS-style scheduling, rich card formatting, and importable JSON decks.

## Features

- Deck-based learning workflow with a clean, card-first interface
- Spaced repetition using a Swift port of FSRS-6 scheduling
- Review grading with Again, Hard, Good, and Easy actions
- Rich card content with formatted text and optional HTML rendering
- Tagging and color-coded card grouping
- Browse/search across all cards and tags
- Deck import from JSON files, including bundled NeetCode sample content
- Daily review statistics and a short-term forecast of due cards

## Screenshots

The app includes:

- Deck list and deck creation flow
- Card editor with rich text and tag entry
- Study session screen with answer reveal and grading buttons
- Statistics dashboard with due forecast and review activity
- Browse view for searching cards across all decks

## Tech stack

- SwiftUI
- SwiftData
- Charts
- UIKit document picker integration for importing JSON files

## Project structure

```text
mangki/
├── README.md
├── Flashcards/
│   ├── FlashcardsApp.swift
│   ├── ContentView.swift
│   ├── DeckDetailView.swift
│   ├── StudyView.swift
│   ├── StatsView.swift
│   ├── BrowseView.swift
│   ├── CardEditorView.swift
│   ├── Models.swift
│   ├── FSRS.swift
│   ├── DeckImporter.swift
│   ├── CardFormatting.swift
│   ├── CodeHighlighter.swift
│   ├── HTMLView.swift
│   ├── StudyCardHeader.swift
│   ├── TagStyle.swift
│   ├── neetcode150.json
│   ├── NeetCodeDeck.json
│   └── Assets.xcassets/
└── ...
```

## Requirements

- macOS with Xcode 15 or newer
- An iOS development target using SwiftUI and SwiftData (iOS 17+ is recommended)
- An Apple Developer account for running on a physical device

## Running the app

1. Open the project in Xcode.
2. Select the Flashcards app target.
3. Choose a simulator or connected iPhone as the run destination.
4. Press Run to build and launch the app.

If you are opening the project from this folder in a Swift package or workspace setup, make sure the Flashcards folder is included in the Xcode project and that the app target builds successfully.

## Using the app

### Creating a deck

From the main deck list, tap Add Deck and give the deck a name. You can then add cards from within the deck detail screen.

### Adding cards

Each card includes a front and back side, optional tags, and rich text formatting. Tags are used to group cards visually and make browsing easier.

### Studying

Open a deck, tap Study Now, and review cards one at a time. The answer is revealed when the card is tapped, and you grade each card using the spaced repetition scheduler.

### Importing decks

The app supports JSON deck import via a document picker. The expected format is:

```json
{
  "version": 1,
  "decks": [
    {
      "name": "Example Deck",
      "cards": [
        {
          "front": "<html>Question</html>",
          "back": "<html>Answer</html>",
          "tags": ["algorithms", "arrays"]
        }
      ]
    }
  ]
}
```

The app also ships with a bundled NeetCode sample deck and automatically imports it on first launch if it has not been added yet.

## Scheduling behavior

The scheduler is based on FSRS-6 memory state tracking rather than a fixed ease-factor formula. Each card maintains:

- memory stability
- memory difficulty
- review count
- last review date
- next review date

This allows the app to estimate recall and generate intervals tuned to the card’s difficulty and review history.

## Notes

- Imported HTML cards are intentionally non-editable in the card editor, since they are treated as formatted content.
- Review logs are stored to support statistics, due-card forecasting, and recall-rate summaries.
- The app is designed for a mobile study workflow rather than a full desktop flashcard management suite.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
