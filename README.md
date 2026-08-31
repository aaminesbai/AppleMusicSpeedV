# MuzakKit - SwiftUI App with MusicKit Integration

MuzakKit is a SwiftUI-based iOS demo app that integrates with Apple Music through the MusicKit framework. The app allows users to explore music recommendations, search the Apple Music catalog or their personal library. It also provides detailed pages for albums, artists, and playlists, as well as the ability to play music if the user has an active Apple Music subscription. 

- App design is a simplified version of the Apple Music App. 
- This demo app is a work in progress, code refactor passes will happen and features will be added or improved:
  - ~~Music player improvements with animation and layout.~~ ✅
  - ~~Add more error handling (view container for loading state)~~ ✅
  - Add blocking screen for users that don't have an apple music subsription.
  - Improved playlist features: editing and creating.
  - General code cleanup.
  - Fix mocked data for SwiftUI previews.
- This app was built to experiment with SwiftUI features by building a complete app that connects to a framework (in this case MusicKit).
- This app loosely followed the [MV pattern](https://azamsharp.com/2022/08/09/intro-to-mv-state-pattern.html) for state management.
- Protocol driven service layer with factory pattern for dependency injection
- Enum based navigation using NavigationStack
- @Observable for state management throughout

## Features

- **Browse Page**: Display music recommendations from Apple Music based on the user's preferences.
- **Search Page**: Search the Apple Music catalog or user's personal library (Playlists, Albums, Artists, Genres).
- **Library Page**: View saved music content such as:
  - Playlists
  - Albums
  - Artists
  - Genres
- **Detail Pages**:
  - Album details with track listing
  - Artist details with discography
  - Playlist details with track listing
- **Music Playback**: Play music directly from the Apple Music catalog if the user has an active subscription.
- **Playback Speed**: Adjust playback speed from the Now Playing screen or Settings.
  
## Prerequisites

- **Apple Developer Account**: Required for using MusicKit and accessing the Apple Music API.
- **Apple Music Subscription**: Required to play music and access full playback features.
- **Xcode 16.2+**: The project currently targets iOS 18.6 for the app target and uses SwiftUI APIs from the Xcode 16 generation.

## Features in Detail

### Browse Page
- Fetches and displays curated music recommendations from Apple Music, allowing users to discover new tracks, albums, and playlists based on their tastes.

### Search Page
- Users can search the Apple Music catalog for music or search their own library for saved content.
- Music results display cover art, titles, and allow users to quickly navigate to albums, artists, or playlists.

### Library Page
- Shows a categorized view of the user's saved content in Apple Music.
  - **Playlists**: A list of user-created or saved playlists.
  - **Albums**: A list of albums the user has added to their library.
  - **Artists**: A list of artists the user follows or has saved.
  - **Genres**: A list of music genres saved by the user.

### Detail Pages
- Each item (album, artist, or playlist) has a dedicated detail page showing more information, such as track lists for albums and playlists, or discographies for artists.
  
### Music Playback
- If the user has an Apple Music subscription, they can play full tracks from the Apple Music catalog directly in the app.
- The app supports basic playback features like play, pause, skip, and volume control.

## Playback Speed

MuzakKit includes a native playback speed control for the existing `ApplicationMusicPlayer.shared` player.

- Supported range: `0.50×` to `2.00×`, using a SwiftUI `Slider` with `0.05` steps.
- Now Playing shows a live speed slider below playback progress, plus presets for `0.75×`, `1×`, `1.25×`, `1.5×`, and `2×`.
- Tapping the displayed speed value resets playback speed to `1.00×` with subtle haptic feedback.
- Settings includes a Playback section with the same shared speed state, a reset action, and a Remember Playback Speed toggle.
- When Remember Playback Speed is on, the preferred speed is saved with `UserDefaults` under `preferredPlaybackRate`.
- When Remember Playback Speed is off, the current queue can still change speed, but new listening sessions and the next app launch start again at `1.00×`.
- The UI keeps a separate preferred speed and actual MusicKit playback rate, so pausing playback does not move the slider to `0×`.
- When playback starts, resumes, skips, or the queue changes, the app reapplies the preferred speed without using timers or private APIs.
- The public MusicKit API used is `MusicPlayer.State.playbackRate` on the existing `ApplicationMusicPlayer.shared.state` object.
- If MusicKit reports a different actual rate while playing, the app leaves playback functional and shows a subtle availability message.

Known limitations:

- MusicKit controls Apple Music playback; the app does not access, download, or manipulate raw Apple Music audio.
- Some playback contexts or tracks may reject speed changes. In that case, the preferred speed remains visible, but the actual rate may differ.
- Actual playback-rate behavior must be verified on an Apple device or simulator signed in with an Apple Music account.

## Building without a Mac

This repository can be edited on Windows and pushed to GitHub, then built on a macOS CI provider such as Codemagic.

Use Xcode's command line tools on macOS. A CI archive command should look like:

```sh
xcodebuild \
  -project MuzakKitApp.xcodeproj \
  -scheme MuzakKitApp \
  -sdk iphoneos \
  -configuration Release \
  archive
```

Do not commit signing certificates, provisioning profile UUIDs, developer credentials, or API keys. Configure signing and Apple Music capabilities in Apple Developer/Xcode or the CI provider's secure settings.

## GitHub Actions CI

Pushes and pull requests run an unsigned iOS Simulator build on GitHub Actions using `macos-latest`.

The workflow lives at `.github/workflows/ios-build.yml` and can also be started manually from the Actions tab with "Run workflow". It prints the selected Xcode version, lists installed SDKs, resolves Swift Package Manager dependencies, and builds the shared `MuzakKitApp` scheme for `generic/platform=iOS Simulator` with code signing disabled.

The project depends on `SFSymbolsMacro`, so CI passes `-skipMacroValidation` to `xcodebuild`. This avoids Xcode's interactive "enable macro" prompt on fresh GitHub runners while still using the pinned package version from `Package.resolved`.

This validates Swift compilation, package resolution, resource processing, and linking. It does not validate real Apple Music authorization, subscription state, catalog playback, or whether a specific Apple Music track accepts `MusicPlayer.State.playbackRate` at runtime. Playback speed behavior still needs testing in a real MusicKit playback environment after the simulator build succeeds.
  
## Libraries & Frameworks Used

- **MusicKit**: To interact with the Apple Music API for fetching catalog data and enabling music playback.
- **SwiftUI**: For building the app’s user interface with a declarative, component-based approach.
  
## Screenshots

### Music Player

https://github.com/user-attachments/assets/3735263d-794a-4bb9-84ba-a9f48b6913fd

### Artist Page

https://github.com/user-attachments/assets/5fa56c01-849c-496f-92af-62f53f6eda37

### Browse Page
<img width="250" src="https://github.com/user-attachments/assets/63004fae-ad5f-482a-8454-82b1c6ee7da8">

### Search Page
<img width="250" src="https://github.com/user-attachments/assets/9eaf9dea-5f6c-44d5-9ac4-afcfd914011d">

### Library Page
<img width="250" src="https://github.com/user-attachments/assets/7c557bcc-3e14-4fd0-ae7d-a3bc711af8a1">

### Album Detail Page
<img width="250" src="https://github.com/user-attachments/assets/e80dca43-7a7a-4134-86a8-834ef674e813">

## Acknowledgements

- Thanks to the [MusicKit Documentation](https://developer.apple.com/documentation/musickit) for the API references and guides.
