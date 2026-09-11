# Radix: migration from React Native macOS to pure Swift

Status: phase 0 done (2026-09-11): `make run` installs a signed
`/Applications/RadixNext.app` that shows the panel. Escape / cmd+space toggle
still need a manual check.
Phase 1 done (2026-09-11): RadixCore has Config, Keys, Search, Parsers with
70 tests green.
Phase 2 done (2026-09-11): AppModel, InputRouter, full HotKeyManager, toasts,
launch at login, config wiring. Verified: build, `make lint`, tests, panel
shows, hides on resign key, reopens. Needs a manual check: Esc, arrows moving
the placeholder selection, cmd+, opening settings, search field focused on
show, `showWindowOn = screenWithFrontmost` on a second display.
Phase 3 done (2026-09-11): search widget, 78 apps / 33 preference panes /
bookmarks loading, 23 built-in items, calculator and conversions inline,
history, usage ranking, confirmation dialog. Verified: release build,
`make lint`, 120 tests (including a new app-level RadixTests target), sources
load at launch, compact panel height. Needs a manual check: typing, running
an app and a built-in item, Enter on a calculator result, the Restart
confirmation (Esc to cancel), clicking empty panel space keeps the search
field focused.
Correction found in phase 4: the phase 3 build crashed whenever anything
changed in an Applications folder (FSEvents callback isolation trap, see
below). Fixed and covered by tests in phase 4.
Phase 4 done (2026-09-11): window management (19 items), dark mode, Wi-Fi
password and QR, `ip` answer, process manager widget, user scripts with a live
folder watcher, per-item global shortcuts, media key forwarding, hyperkey.
Verified: release build, `make lint`, 150 tests, app runs, SIGTERM exits
through normal termination, no new crash reports, system hooks stay off while
the old build runs (key mapping untouched). Compiled but not exercised (needs
permissions, prompts or hardware keys): window moves, Spaces moves, media
keys, hyperkey, Wi-Fi keychain lookup, appearance toggle, script execution.
Manual check: quit the old Radix, grant RadixNext Accessibility, then try a
window shortcut (⌃⌥←), Kill process on a harmless app, a script in
~/.config/radix/scripts, and play/pause with Music or Spotify running.
Phase 5 done (2026-09-11): clipboard manager, Spotlight file search,
translation, scratchpad, create/edit Quick Links with SF Symbol icons.
Verified: release build, `make lint`, 209 tests, app runs through a
pasteboard change with no crash report, live Spotlight query (~0.1 s) and live
Google translation (0.4 to 1.7 s) from the forks. Needs a manual check:
scratchpad typing and focus, Tab and Enter in the Quick Link form, pasting a
clipboard entry (text and image) into another app, ⇧Enter translation,
file search Enter and ⇧Enter, copying a file in Finder (should be recorded as
the file, not its icon).
Only the settings widget is still a placeholder.
Phase 6 done (2026-09-11): settings with General, Translation, Items,
Scripts and About pages, shortcut recording, enable/disable items, config
reload. Every config.json key is editable from the UI except `keymap` (hand
edited, as before) and `scratchPadColor` (feature dropped). Verified: release
build, `make lint`, 225 tests, app runs. Needs a manual check: ⌘, opens
settings; record a shortcut for an item and use it (with the old Radix
quit); Add Folder picker returns to settings and keyboard works in the
picker; Tab and Esc inside the custom search URL field.
Phase 7 (cutover) partly done (2026-09-11):
- Done: bundle id back to `com.svenbakkenes.radix`, app name Radix, version
  2.0.0. `make install` replaced /Applications/Radix.app with the Swift build
  (same designated requirement as the old app, so permission grants carry
  over; no tccutil reset was needed). The old React Native app is backed up at
  `dist/Radix-react-native-1.0.0.zip`. README, `.gitignore` and
  `scripts/bump-version.sh` rewritten; `scripts/build-local.sh` superseded by
  `make install`; JetBrains Mono removed. Verified: release build, `make lint`
  (exit 0), 225 tests, installed app runs, no crash report.
- Not done (deletion blocked by the auto-mode safety check, needs the user):
  removing the React Native tree from the repo and
  /Applications/RadixNext.app. Commands:

  ```sh
  rm -rf macos src patches node_modules build .github .vscode index.js \
    package.json bun.lock babel.config.js metro.config.js tailwind.config.js \
    biome.json tsconfig.json nativewind-env.d.ts app.json mise.toml .prettierrc \
    scripts/build-local.sh
  rm -rf /Applications/RadixNext.app
  ```

  Then drop the "Leftovers of the React Native build" block from .gitignore.
  The uncommitted change to macos/sol.xcodeproj/project.pbxproj only reorders
  two SFSymbol entries, so nothing is lost with it.
- Optional: the old file search index, `~/Library/Application Support/Radix`
  (18 MB), is unused by the Swift app.
- Not verified: login item registration and system hooks (media keys) on the
  installed app; NSLog output doesn't reach `log show`. Check Settings >
  General and System Settings > General > Login Items.

Decisions made during phase 6:
- Shortcut recording needs no event tap: Radix's own item shortcuts are
  unregistered while recording and keys arrive through the panel's key
  monitor. System-reserved combos (⌘Tab and the like) can't be recorded.
- Recorded keys come from the physical key (as registration does), not the
  typed character. Item shortcuts need ⌘, ⌥ or ⌃; ⌘/⌥/⌃+Space are reserved
  for the launcher; duplicates are detected by key and modifiers, not string,
  and the error names the item using it.
- After a successful recording the shortcuts stay unregistered for the
  1.2 s the result is shown, so releasing the keys can't run the item; hiding
  the panel mid-recording always re-registers them.
- The launcher toggle is registered after item shortcuts are removed, so an
  item can never take the toggle combo.
- The panel's key monitor only handles events for the panel window; other
  windows (the folder picker) keep their keys. The picker hands focus back to
  the previously active app.
- Config changes re-apply only what changed (screen preference, hotkeys,
  media keys and hyperkey, login item); Reload Config re-applies everything.
- File Search Paths has no Re-index button: Spotlight maintains its own index.

Decisions made during phase 5:

Decisions made during phase 5:
- File search uses Spotlight (NSMetadataQuery on the configured folders)
  instead of the SQLite index. The old search only ever looked at 1000 rows of
  an 18 MB index. Folders excluded from Spotlight return nothing. The old
  ~/Library/Application Support/Radix/filesearch.db can go at cutover.
- Weather and GitHub search were dropped (never used). The scratchpad colour
  cycling was dropped (never rendered); Tab types a tab.
- Custom item icons are SF Symbols. Old PNG icon names map to symbols (11
  without a close match show a star); an unchanged legacy icon keeps its
  stored name on edit so the old build still shows it. 114 PNGs no longer
  ship. JetBrains Mono is bundled but unused: remove at cutover.
- Clipboard history is a 0600 JSON file (only when `saveHistory` is on) instead
  of the Keychain; with saving off the file is deleted. Copied images are 0600
  in a 0700 directory. Password manager copies (Concealed, Transient,
  AutoGenerated types) are not recorded. Radix's own re-pastes are not recorded
  again.
- A copied file is recorded by its original path. The old build copied it into
  the temporary directory, deleting anything with the same name there first
  (and a copied volume root would have deleted the temporary directory).
  Only image files are copied into the managed images directory, off the main
  thread. File URLs take priority over image data (Finder icons).
- Orphaned clipboard images are only cleaned up when no other Radix build is
  running and, with history saving on, only once this build has its own
  history file.
- Lists that change while visible (processes, clipboard, file search) select
  by identity through one `Selection` type, so Enter never acts on a row that
  shifted underneath.
- Translation keeps the unofficial Google endpoint (still working in 2026);
  failed rows show their error instead of "Translating..." forever. Apple's
  on-device Translation framework is the fallback if Google breaks it.
- The note saves 500 ms after typing pauses, and on hide and quit; sudden
  termination is disabled while a note or clipboard save is pending.
- Tests inject translation and clipboard storage, so they never reach the
  network or ~/.config/radix.

Decisions made during phase 4:
- System-wide hooks (per-item shortcuts, media key tap, hyperkey) install
  only while no other Radix build (release or old debug id) is running, and
  follow it launching or quitting. The main ⌘Space toggle is unaffected.
- DoNotDisturb and now-playing media info were dropped: the old JS never
  called them. That also removes the private MediaRemote dependency.
- C callbacks invoked off the main thread (FSEvents) are top-level functions.
  Closures written inside @MainActor code inherit its isolation and Swift 6
  traps on the runtime check. Event taps and the Carbon handler stay closures
  only because they run on the main run loop; comments mark this.
- One DirectoryWatcher serves the application and script loaders; it also
  rescans when FSEvents reports dropped events.
- The process manager tracks selection by pid. The list re-sorts every 5 s,
  and a row index could redirect SIGKILL to another process. A failed kill is
  reported instead of silently ignored.
- Media keys pass through when Music, Spotify and Kaset are all closed, so
  browser and system Now Playing keep working.
- The hyperkey only adds and removes its own Caps Lock to F18 hidutil entry
  (the old build wiped every mapping), disables sudden termination while the
  remap is active, and SIGTERM is routed through normal termination so the
  remap is removed. Hardware events only get the hyper modifiers; state resets
  when the tap is disabled or F18 is no longer physically held. hidutil still
  runs synchronously on the main thread (off by default for this config).
- Wi-Fi keychain lookup and AppleScript run off the main thread; Accessibility
  calls to the frontmost app time out after 1 s.
- Shortcuts to destructive items show the panel and ask for confirmation.
  Shortcuts to items that switch widgets reshow the panel (`keepsPanelOpen`).
  Phase 5: clipboard_manager and scratchpad need `keepsPanelOpen` to keep the
  old shortcut behaviour.
- Script output is read on one serial queue, stops at EOF, and keeps
  multi-byte characters split across reads intact.

Decisions made during phase 3:

Decisions made during phase 3:
- Search is a name-dominant fuzzy match with usage-first ranking (from
  phase 1). Kill All Apps now asks for confirmation, since fuzzy matching makes
  it easier to hit than before; Restart, Shut Down, Empty Trash already did.
- A held Enter never confirms; only a fresh press runs an item or accepts a
  confirmation.
- Saves write only the keys whose values changed since the last load or save,
  so the old build's edits to other keys survive while both run.
- AppleScript runs on a serial background queue (as the old build did), so a
  slow Finder or Safari reply no longer freezes the panel or hotkeys. Google
  Meet polling moved from AppleScript `delay` into Swift.
- Query history is capped at 200 entries (the old build grew state.json
  without bound).
- Shift+Enter shows "Translation is not available yet" until phase 5; the
  footer's "Edit ⌘E" hint returns with the create-item widget.
- PNG assets were replaced by SF Symbols and app icons, so the bundle ships no
  image resources.
- Preference panes use the System Settings icon (most panes have no plist
  icon); pane names without a plist display name are derived from the file
  name instead of showing "prefPane".
- Paste as JSON keeps key order but Foundation writes `"key" : value`.
- The shell output helper was removed until scripts need it (phase 4).

Decisions made during phase 2:
- Per-item global shortcuts and launch at login only activate under the final
  bundle id `com.svenbakkenes.radix`. Carbon lets two processes register the
  same combo, so the migration build would silently compete with the old app.
- Modifier state comes from each key event only. The old sticky
  flagsChanged state went stale across a hide and could turn letters into
  chords.
- Tab (cycleScratchpadColor) is consumed only in the scratchpad, so settings
  keeps focus traversal.
- The main toggle fires on key-down; settings and item shortcuts on key-up.
- Overlay window and status bar title were dropped: the old JS declared them
  but never called them.
- Tooling: `.swift-format` config plus `make fmt` and `make lint` (strict). Toolchain at time of writing: Swift 6.3, Xcode 26.6,
macOS 26.6, signing identity "MyLauncher Local Signing".

## Goal

Replace the React Native layer (React 19, Hermes, Fabric, Metro, CocoaPods,
Babel, patched deps, JSI bridge) with a SwiftPM-based AppKit + SwiftUI app.
Single machine, no cross-platform, no upstream Sol tracking. Reuse the ~8k
lines of existing Swift under `macos/sol-macOS` where it is not bridge glue.

## Why SwiftPM instead of an Xcode project

- `swift build` in seconds, no pbxproj merges, no CocoaPods.
- `sourcekit-lsp` understands `Package.swift` natively, so Neovim gets
  completion and diagnostics without xcode-build-server.
- `swift test` runs the pure-logic tests without launching the app.
- Cost: SwiftPM does not produce a `.app`. A ~40-line Makefile assembles the
  bundle (binary, Info.plist, resources, icon) and codesigns it. No asset
  catalogs or storyboards; the app is 100% programmatic, icon is a `.icns`.

## Target layout

```
Radix/                          repo root (this repo, after cutover)
  Package.swift
  Makefile                      build / bundle / sign / install / run
  Sources/
    RadixCore/                  library, NO AppKit import, fully testable
      Config/                   Codable models for config.json + state.json
      Search/                   fuzzy scorer, ranking (frequency/recency)
      Parsers/                  calculator, unit conversion, timezone, URL detection
      Keys/                     keycodes, chord parsing, shortcut normalisation, keymap
      Items/                    Item model + built-in catalog definitions (data only)
    Radix/                      executable, AppKit + SwiftUI
      App/                      main.swift, AppDelegate, StatusBarItem, LaunchAtLogin
      Panel/                    Panel (NSPanel), PanelManager, Overlay, Toast
      Input/                    HotKeyManager (Carbon RegisterEventHotKey), key routing, hyperkey tap
      System/                   ported lib/: WindowManager, AccessibilityElement, ClipboardHelper,
                                ApplicationSearcher, ShellHelper, AppleScriptHelper, FS,
                                FolderWatcher (FSEvents), Processes, DarkMode, DoNotDisturb,
                                QRGenerator, ScreenDetector, NotchHelper, MediaHelper, MediaKeyForwarder
      Store/                    @Observable AppState, ConfigStore (JSON on disk), ClipboardStore, ScriptsStore
      Widgets/                  SwiftUI views: Search, Clipboard, FileSearch, Processes,
                                Scratchpad, Translation, CreateItem, Settings/*
      Services/                 URLSession clients: Translator, Weather, GitHub
  Tests/
    RadixCoreTests/
  Resources/
    Info.plist
    Radix.entitlements
    Radix.icns
    JetBrainsMono.ttf
  docs/
```

Two targets only. `RadixCore` must not import AppKit so tests stay fast and
the logic stays honest. Everything that touches the OS lives in the
executable. Split further only if a real reason appears.

Swift 6 language mode from day one. Almost everything is `@MainActor`
(AppKit); the few background pieces (file indexer, pasteboard polling,
network) use structured concurrency.

## What happens to each existing native file

Delete (bridge only): `SolNative.swift`, `SolNative.mm`, `SolEmitter.swift`,
`JSIBindings.mm/.hpp`, `JSIUtils.h/.mm`, `SolMacros.h`,
`FileSearchIndexObjC.swift`, `FolderWatcherJSIBridge.swift`,
`sol-macOS-Bridging-Header.h`, `BlurView.m`, `FileIcon.m`, `GradientView.m`,
`SFSymbol.m`, `KeyboardShortcutRecorderView.m`.

Strip glue, keep logic: `AppDelegate.swift` (drop RCTAppDelegate), `PanelManager`,
`HotKeyManager`, `StatusBarItemManager` (replace `SolEmitter.*` calls with
closures / an `InputRouter`), `MediaKeyForwarder` (drop RCTLog import),
`FolderWatcherJSI.mm` (keep the FSEvents core, rewrite in Swift),
`BlurView/GradientView/SFSymbol/FileIcon/KeyboardShortcutRecorderView.swift`
(drop `RCTViewManager` subclasses; BlurView/GradientView/SFSymbol/FileIcon
become SwiftUI `Image`/`NSViewRepresentable` or disappear entirely).

Port as-is: everything else in `lib/`, `extensions/`, `views/Panel.swift`,
`Overlay.swift`, `Toast*.swift`, `ShellOutputView.swift`, `ToastManager.swift`.

Rewrite in Swift instead of keeping ObjC (SwiftPM cannot mix ObjC and Swift
in one target; these are small): `NSString+Score.m` (129 lines),
`processes.mm` (sysctl kinfo_proc), `MediaKeyForwarder.m`.

Replace: vendored `KeychainAccess.swift` (3143 lines) with either ~60 lines of
Security.framework calls or, simpler, drop Keychain for clipboard history and
write it to `~/.config/radix/clipboard.json` with 0600 permissions.
`HotKey` pod with a direct Carbon `RegisterEventHotKey` wrapper (~80 lines).

## JS dependency replacements

| JS | Swift |
|---|---|
| MobX stores | `@Observable` classes in `Store/` |
| config.json / state.json via JSI FS | `Codable` + `JSONEncoder` (keep file format so old and new builds coexist) |
| minisearch + compareRankedItems | own fuzzy scorer (port of NSString+Score) + frequency/recency tiebreak |
| expr-eval | small Pratt-parser calculator in RadixCore (NSExpression is too limited) |
| convert-units | Foundation `Measurement` / `Dimension` units |
| chrono-node | `NSDataDetector` (.date) |
| luxon | `Date`, `TimeZone`, `DateFormatter` |
| axios | `URLSession` + `Codable` |
| nanoid / uuid | `UUID()` |
| nativewind / tailwind / reanimated | SwiftUI |
| @legendapp/list | SwiftUI `List` or `LazyVStack` inside `ScrollView` |

## Architecture rules for the UI

- The panel is AppKit: `Panel: NSPanel` with `.nonactivatingPanel`,
  `canBecomeKey = true`, `NSVisualEffectView` content, exactly as today.
- SwiftUI content is hosted via `NSHostingView` inside the effect view.
- Keyboard: keep the local `NSEvent` monitor in `HotKeyManager`. It dispatches
  to an `InputRouter` (esc, arrows, enter, tab, cmd+1..9, modifier state).
  SwiftUI views never handle navigation keys. The search field is the only
  first responder; the list is driven by `AppState.selectedIndex`.
- Widgets are an enum in `AppState`; the panel swaps the hosted root view
  based on it, mirroring `ui.store`'s focusedWidget.

## Migration phases

Each phase ends with a build that is installed and used. Do not start the
next phase before the exit criterion is met.

### Phase 0: skeleton (day 1)
- `Package.swift`, two targets, tests target.
- `Makefile`: `build`, `bundle`, `sign`, `install`, `run`, `clean`.
  Bundle id `com.svenbakkenes.radix.swift` during the migration so the RN
  build keeps its Accessibility grant; share `~/.config/radix`.
- `Info.plist` from the current one minus RN keys (`RCTNewArchEnabled`,
  `NSAppTransportSecurity`, storyboard). Keep `LSUIElement`,
  usage descriptions, font path.
- Entitlements: current `sol-macOS.entitlements` minus
  `disable-library-validation`. Unsandboxed.
- `main.swift` + AppDelegate: accessory activation policy, status bar item,
  empty `Panel` toggled by cmd+space through the Carbon hotkey wrapper.
- Exit: `make install` produces a signed app in /Applications that shows and
  hides a blurred panel on cmd+space, the Accessibility prompt appears once,
  and `sourcekit-lsp` resolves symbols in Neovim.

### Phase 1: RadixCore (pure logic, with tests)
- Port `ui.store.helpers.ts`: unit conversion parser, timezone parser,
  `formatExpressionResult`. Drop flight lookup unless wanted.
- Port `keys.ts`, `keymap.ts`, `shortcuts.tsx`, `search.ts`, `constants.ts`.
- Port `NSString+Score.m` to Swift; add the frequency/recency ranking from
  `ui.store.tsx` (~line 171).
- Write the calculator (Pratt parser: + - * / ^ %, parens, unary minus,
  common functions).
- Config models mirroring `PORTABLE_KEYS` and `RUNTIME_CONFIG_KEYS`; a
  `ConfigStore` that reads/writes the existing JSON files unchanged.
- Exit: `swift test` green; tests load a copy of the real `config.json`.

### Phase 2: shell + input
- Port `Panel`, `PanelManager`, `Overlay`, `Toast*`, `ToastManager`,
  `StatusBarItemManager`, `ScreenDetector`, `MouseUtils`, `NotchHelper`.
- Port `HotKeyManager` minus SolEmitter; add `InputRouter`; keep the
  arrow/enter swallow toggles as state on the router.
- Launch at login with `SMAppService`.
- Exit: panel positions on the right screen per `showWindowOn`, resizes,
  hides on resign key, cmd+, opens the (empty) settings widget.

### Phase 3: search widget, daily-drivable
- Port `ApplicationSearcher`, `FS`, `ShellHelper`, `AppleScriptHelper`.
- Port `items.tsx` into a Swift built-in catalog (`Item` struct, action
  closures), and `systemPreferences.tsx`.
- `AppState` (query, results, selection, frequencies, history) and the
  `SearchWidget` SwiftUI view with previews for calculator / units / timezone
  / URL / search-engine fallback.
- Exit: replaces the RN build for launching apps and running items. Switch
  daily use to the Swift build here.

### Phase 4: system items
- Port `WindowManager`, `AccessibilityElement`, `DarkMode`, `DoNotDisturb`,
  `QRGenerator` (WiFi QR), Processes (Swift sysctl) + `ProcessesWidget`.
- Scripts: FSEvents watcher in Swift, `ScriptsStore`, shell/AppleScript run,
  `ShellOutputView`.
- Custom hotkeys per item (`updateHotkeys`) and hyperkey tap.
- Exit: every item in `items.tsx` works or is consciously dropped.

### Phase 5: clipboard, file search, remaining widgets
- Clipboard: port `ClipboardHelper` + images_pasteboard; `ClipboardStore`
  persisted to JSON (Keychain dropped); `ClipboardWidget`.
- File search decision: port `FileSearchIndex/Indexer` (SQLite via
  `import SQLite3`) OR switch to `NSMetadataQuery`. Default: try
  NSMetadataQuery first, it removes ~600 lines and the indexer; fall back to
  the port only if Spotlight scope/latency is unacceptable.
- Scratchpad, Translation (`translator.ts` → URLSession), CreateItem widget.
- Weather / GitHub search: port only if still used.
- Exit: feature parity with the RN build, except anything explicitly dropped.

### Phase 6: settings
- Settings widget with sidebar: general (hotkey recorder, launch at login,
  show-window-on, search folders via NSOpenPanel), items (enable/disable,
  rebind), scripts, translate, about.
- `KeyboardShortcutRecorder` as `NSViewRepresentable`.
- Exit: every key in `config.json` is editable from the UI.

### Phase 7: cutover
- Bundle id back to `com.svenbakkenes.radix`; `permissions:reset` once.
- Delete `macos/`, `src/`, `index.js`, `package.json`, `bun.lock`,
  `node_modules`, `patches/`, babel/metro/tailwind/biome/tsconfig files,
  `mise.toml`, `.vscode/`.
- Rewrite `README.md` and `scripts/` (build-local.sh becomes `make install`;
  bump-version.sh edits Info.plist).
- Update `.gitignore` (drop node/RN entries, add `.build/`, `dist/`).

## Known risks

- `MediaHelper.swift` uses the private MediaRemote framework. Apple restricted
  third-party access from macOS 15.4. Verify on 26.6 before porting; if
  broken, drop now-playing or use the mediaremote-adapter helper approach.
- Carbon `RegisterEventHotKey` is deprecated but still works on macOS 26.
  Fallback is the CGEvent tap already used for the hyperkey.
- SwiftUI inside a non-activating panel can steal first responder from the
  search field. Mitigation is architectural (rule above); budget a day.
- Safari bookmarks need Full Disk Access. Keep only if actually used.
- TCC grants are keyed on bundle id + signature. Keep the self-signed
  identity stable and expect one re-grant at cutover.

## Decisions to confirm

1. Drop Keychain for clipboard history (plain JSON file)? Default: yes.
2. NSMetadataQuery vs ported SQLite index for file search? Default: try
   NSMetadataQuery first.
3. Keep flight lookup, GitHub search, weather, Safari bookmarks? Default: drop
   flight lookup; keep the others only if used weekly.
4. Build inside this repo under the layout above, deleting RN at cutover
   (keeps git history), vs a fresh repo? Default: this repo.
