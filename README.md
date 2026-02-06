# Disciplo

Disciplo is a focus + missions (quests) app with a light RPG-style progression system.

## Progression rules

- XP required to reach the next level increases after every level-up.
- On each level-up, the AI auto-allocates **2–3 stat points** based on what you did that level.
- Every **5 levels**, you earn **+1 stat point** that you can allocate manually.

## Cloud sync (Google Drive)

This app includes an optional Google Drive sync that stores backups in your Google Drive **AppData** folder (hidden from the normal Drive UI).

### What it does

- Uploads a single `focus_flutter_latest.json` (plus an optional daily snapshot)
- Downloading will **overwrite local data**
- Optional **Auto-upload** toggle (best-effort, debounced)

### Setup notes

Google Drive sync requires Google OAuth configuration:

1. Create a Google Cloud project
2. Enable **Google Drive API**
3. Configure **OAuth consent screen**
4. Configure OAuth client IDs for your target platforms (Android/iOS/Web)

If OAuth is not configured, sign-in may appear to work but Drive upload/download can fail.

#### Windows/Linux (desktop) notes

Google sign-in on Windows/Linux uses a **desktop OAuth** flow (browser-based) and requires a **Desktop** OAuth client ID/secret.

1. In Google Cloud Console, create an **OAuth client ID → Desktop app**
2. Enable **Google Drive API** for the project
3. Run the app with desktop credentials via `--dart-define` (recommended: keep them in a local `.env`):

- Put values in `.env`:
	- `GOOGLE_OAUTH_DESKTOP_CLIENT_ID`
	- `GOOGLE_OAUTH_DESKTOP_CLIENT_SECRET`
- Then run:
	- `flutter run --dart-define-from-file=.env`

## Getting started

This is a Flutter app. Open the project in VS Code, then run it on a device/emulator.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
