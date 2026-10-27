# MyContributions

A macOS menu bar app that shows a GitHub user's public contributions: today's count in the menu bar, and this week's days in the dropdown. No token, no Xcode, no Apple ID.

## Layout

| Path | What it is |
| --- | --- |
| `MenuBar/` | The menu bar app (SwiftUI `MenuBarExtra`) and its `Info.plist` |
| `Shared/` | Reads `github.com/users/<name>/contributions` |
| `Package.swift` | Swift Package Manager manifest |
| `build.sh` | Builds and signs `build/MyContributions.app` for local use |

## Build and run

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```sh
./build.sh
open build/MyContributions.app
```

Click the GitHub icon in the menu bar, type a GitHub username, and press Return. The username is saved, and the count refreshes every 30 minutes, right after midnight, and whenever you open the dropdown (if the data is more than 5 minutes old). "This week" starts on the first weekday set in your Mac's region settings.

To keep it around, drag `build/MyContributions.app` into `/Applications`. To start it at login, add it in System Settings → General → Login Items.

After changing the code, run `./build.sh` again, then choose **Quit** in the dropdown and reopen the app. A running copy keeps the old code, and a copy in `/Applications` has to be replaced by hand.

## Caveats

- This reads the HTML fragment GitHub's profile page uses. It isn't an official API, so a GitHub markup change could break it. The parsing is in `ContributionsService.parseCounts`.
- Private contributions only count if that user turned on *Include private contributions on my profile*.
- GitHub decides which calendar day a contribution falls on. For an anonymous request that may not match your local time zone, so late-evening commits can land on the next day.
