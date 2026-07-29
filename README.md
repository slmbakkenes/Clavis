# Radix

A personal macOS launcher, built for one machine. It makes no attempt to be
configurable for anyone else's setup.

Radix is a fork of [Sol](https://github.com/ospfranco/sol) by ospfranco (MIT).
Auto-update, crash reporting and the release/notarization pipeline have been
removed; it is built locally and signed with a self-signed certificate.

## Requirements

- Xcode
- [bun](https://bun.sh)
- [CocoaPods](https://cocoapods.org)
- A local code-signing certificate named `MyLauncher Local Signing`

## Setup

```sh
bun install
bun pods
```

Xcode build phases don't inherit your shell's `PATH`, so point them at a stable
node binary via `macos/.xcode.env.local` (gitignored):

```sh
echo 'export NODE_BINARY=/path/to/node' > macos/.xcode.env.local
```

## Two ways to run it

**Development** — hot reload, needs Metro running in a terminal:

```sh
bun start     # terminal 1: Metro bundler on :8081
bun macos     # terminal 2: build + run the debug scheme
```

The debug build loads its JS from Metro, so it shows a blank window (or a red
error) if Metro isn't running. Edits to `src/` reload live; changes under
`macos/` need a rebuild.

**Release** — self-contained, no Metro, this is what you actually use day to day:

```sh
bun run build             # build, install to /Applications, launch
bun run build --no-open   # build and install without launching
bun run build --clean     # discard the incremental cache first
```

The JS is bundled into the app, so it runs standalone. The build cache lives in
`build/release-derived`, so the first build is slow (~10-20 min, it compiles all
of React Native) and later ones are incremental.

Debug and release use different bundle identifiers
(`com.svenbakkenes.radix.debug` / `com.svenbakkenes.radix`), so they hold
**separate** macOS permission grants and can be installed side by side. They do
**share** `~/.config/radix/`, so settings, scripts and clipboard history carry
across - don't run both at once, or they'll both grab the global hotkey and
fight over the config file.

## First run

- **Global hotkey** is `option`+`space` by default (`globalShortcut` in
  config.json, one of `command` / `option` / `control`). If upstream Sol is also
  running, both will grab the same chord.
- **Accessibility** is required for window management and paste-to-frontmost.
  Grant it from the prompt in the panel footer, or search for
  "Grant Accessibility Access".
- **Full Disk Access** is only needed for Safari bookmarks. Search for
  "Open Full Disk Access Settings".
- **Launch at login is on by default**, so installing and launching the release
  build registers Radix as a login item. Turn it off in Settings, or set
  `"launchAtLogin": false` in config.json.

Because signing is self-signed and stable, permission grants survive rebuilds.

## Updating

There is no auto-update. Re-run `bun run build`; it quits the running instance,
replaces `/Applications/Radix.app` and relaunches.

## Uninstalling

```sh
rm -rf /Applications/Radix.app
rm -rf ~/.config/radix
```

Then remove the login item in System Settings > General > Login Items.

## Signing

Manual signing against a self-signed certificate — no Apple Developer account
required. The certificate must exist in your login keychain as
`MyLauncher Local Signing`.

Two consequences worth knowing:

- A self-signed certificate carries no Team ID, so hardened-runtime library
  validation would reject the embedded `hermes.framework`. The
  `com.apple.security.cs.disable-library-validation` entitlement allows it.
- `ENABLE_DEBUG_DYLIB` is `NO`, because Xcode's split debug dylib fails to load
  under non-Apple signing identities.

## Configuration

Settings live in `~/.config/radix/config.json`, runtime state (usage
frequencies, query history, scratchpad) in `~/.config/radix/state.json`. Shell
and AppleScript files dropped into `~/.config/radix/scripts` are picked up
automatically - give them a `# name:` and `# icon:` comment.

### In-panel keybindings

The keys the panel reacts to while open are remappable via a `keymap` object in
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

`null` unbinds a default. Available actions: `confirm`, `dismiss`, `selectNext`,
`selectPrevious`, `selectLeft`, `selectRight`, `deleteSelected`, `editSelected`,
`cycleScratchpadColor`. Chord format is `control+command+shift+<key>` using the
key names in `src/lib/keys.ts`.

Prefer chords with a modifier: a bare letter still reaches the search input, so
`"n": "selectNext"` would both type "n" and move the selection.

Unlike everything else in config.json, `keymap` is read-only - the app never
writes it back, so hand edits and `null` unbinds are preserved. Settings >
General > Reload Config re-reads it without a restart.

These are separate from the **global hotkeys** that work anywhere (window
snapping, clipboard manager, etc.); those are the `shortcuts` object, editable
from Settings > Items.

## License

MIT — see [LICENSE](LICENSE). Retains the original Sol copyright.
