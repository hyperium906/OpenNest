# OpenNest

A SwiftUI journaling app that pairs daily reflection with AI-assisted analysis. Users write entries, track progress over time, and browse a gallery of past journals — with optional therapist notification when the model detects concerning patterns.

## Features

- **Journal composer** — write entries with mood capture
- **Progress hub** — visualize trends across your journaling history
- **Journal gallery** — browse and revisit prior entries
- **AI analysis** — entries are sent to a backend endpoint for sentiment/insight analysis
- **Onboarding tutorial** — a first-launch walkthrough introduces the paged interface
- **Launch screen** — animated splash on app open

## Project structure

```
OpenNest/
├── OpenNestApp.swift       # App entry point
├── ContentView.swift       # Root view, paged TabView, launch + tutorial
├── HomeView.swift          # Journal composer screen
├── SecondaryViews.swift    # ProgressHubView, JournalGalleryView, tutorial
├── Components.swift        # Shared UI components and theming
├── JournalModels.swift     # JournalViewModel, services, data models
└── Assets.xcassets/        # App icon and color assets
```

## Backend

The app talks to a journal analysis endpoint configured in `AppConfiguration`:

```swift
static let journalAnalysisEndpoint = URL(string: "http://127.0.0.1:3000/api/analyze-journal")!
```

A `MockGeminiJournalService` is included for previews and offline development.

## Requirements

- Xcode 16+
- iOS 17+
- Swift 5.9+

## Getting started

1. Clone the repo
2. Open `OpenNest.xcodeproj` in Xcode
3. Run the backend service on `127.0.0.1:3000` (or update `AppConfiguration.journalAnalysisEndpoint`)
4. Build and run on simulator or device
