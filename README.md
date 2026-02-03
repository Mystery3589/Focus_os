# focus_flutter

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

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
