# Radix

A personal macOS launcher, built for one machine. It makes no attempt to be
configurable for anyone else's setup.

Radix started as a fork of [Sol](https://github.com/ospfranco/sol) by ospfranco
(MIT) and was rewritten from React Native to Swift. Auto-update, crash
reporting and notarization are not part of it; it is built locally and signed
with a self-signed certificate.

## Requirements

- macOS 14 or later
- Xcode command line tools with Swift 6
- A code-signing certificate named `MyLauncher Local Signing` in the login
  keychain. `scripts/create-signing-cert.sh` creates one.

## Building

```sh
make run       # build, bundle, sign, install to /Applications, launch
make install   # same without launching
make test      # swift test
make lint      # swift-format, strict
make fmt       # format Sources and Tests in place
make debug     # debug build run from .build (no bundle, no login item)
make clean
```

`make install` quits a running instance before replacing
`/Applications/Radix.app`. There is no auto-update; re-run it after pulling.
`scripts/bump-version.sh` bumps the version in `Resources/Info.plist`.

## Layout

- `Sources/RadixCore`: pure logic without AppKit (config, search ranking,
  parsers, calculator, shortcuts, clipboard history, translation parsing).
  Fully unit tested.
- `Sources/Radix`: the app. An AppKit non-activating panel hosting SwiftUI
  widgets, global hotkeys, OS integrations (windows, clipboard, Spotlight,
  scripts, media keys, hyperkey).
- `Tests/RadixCoreTests`, `Tests/RadixTests`: swift-testing suites. The app
  tests use temporary config directories and never touch the network.
- `docs/swift-migration.md`: how the port was done and the behaviour
  decisions made along the way.

## First run

- **Global hotkey** is `option`+`space` by default (Settings > General, or
  `globalShortcut` in config.json).
- **Accessibility** is needed for window management, paste-to-frontmost,
  per-item global shortcuts, media keys and the hyperkey. Grant it from the
  prompt in the panel, or search for "Grant Accessibility Access".
- **Full Disk Access** is only needed for Safari bookmarks.
- **Launch at login is on by default.** Turn it off in Settings > General.

Because the bundle id and signing identity are stable, permission grants
survive rebuilds.

## Configuration

Settings live in `~/.config/radix/config.json`, runtime state (usage
frequencies, query history, scratchpad) in `~/.config/radix/state.json`.
Everything except `keymap` is editable in Settings. Shell (`.sh`) and
AppleScript (`.applescript`) files in `~/.config/radix/scripts` are picked up
as you save them; give them `# name:` and `# icon:` comments.

### In-panel keybindings

Keys the panel reacts to while open are remappable with a `keymap` object in
config.json, mapping a chord to an action:

```json
{
  "keymap": {
    "control+n": "selectNext",
    "control+p": "selectPrevious",
    "down": null
  }
}
```

`null` unbinds a default. Actions: `confirm`, `dismiss`, `selectNext`,
`selectPrevious`, `selectLeft`, `selectRight`, `deleteSelected`,
`editSelected`. Chords are `control+command+shift+<key>` with the key names in
`Sources/RadixCore/Keys/Key.swift`. Prefer chords with a modifier: a bare letter
still reaches the search field. The app never writes `keymap` back; Settings >
General > Reload Config re-reads it.

Global shortcuts that work anywhere (window snapping, clipboard manager and so
on) are the `shortcuts` object, editable in Settings > Items.

## Uninstalling

```sh
rm -rf /Applications/Radix.app
rm -rf ~/.config/radix
```

Then remove the login item in System Settings > General > Login Items.

## License

MIT, see [LICENSE](LICENSE). Retains the original Sol copyright.
