import { chordFromKey, type KeyName, type Modifiers } from "./keys";

/**
 * Semantic in-panel actions. Widgets implement the subset they care about;
 * see stores/keystroke.actions.ts.
 */
export type PanelAction =
	| "confirm"
	| "dismiss"
	| "selectNext"
	| "selectPrevious"
	| "selectLeft"
	| "selectRight"
	| "deleteSelected"
	| "editSelected"
	| "cycleScratchpadColor";

export const PANEL_ACTIONS: readonly PanelAction[] = [
	"confirm",
	"dismiss",
	"selectNext",
	"selectPrevious",
	"selectLeft",
	"selectRight",
	"deleteSelected",
	"editSelected",
	"cycleScratchpadColor",
];

/**
 * Chord -> action. Lookup is two-level: the full chord is tried first, then the
 * bare key. So "shift+enter" falls back to "enter" (still reaching the handler
 * with shift set), while an explicit "shift+enter" entry can override it.
 *
 * Chord format is "control+command+shift+<key>", modifiers in that order, using
 * the key names in lib/keys.ts.
 *
 * Prefer chords with modifiers. Binding a bare letter still lets that letter
 * reach the search input (only the keys in HotKeyManager.handledKeys are
 * swallowed natively), so "n": "selectNext" would both type "n" and move the
 * selection.
 */
export type Keymap = Record<string, PanelAction>;

export const defaultKeymap: Keymap = {
	enter: "confirm",
	escape: "dismiss",
	down: "selectNext",
	up: "selectPrevious",
	left: "selectLeft",
	right: "selectRight",
	"control+j": "selectNext",
	"control+k": "selectPrevious",
	"shift+delete": "deleteSelected",
	"command+e": "editSelected",
	tab: "cycleScratchpadColor",
};

const isPanelAction = (value: unknown): value is PanelAction =>
	typeof value === "string" && PANEL_ACTIONS.includes(value as PanelAction);

/**
 * Merges user overrides over the defaults, dropping entries whose action is not
 * recognised so a typo in config.json can't silently swallow a key.
 */
export function resolveKeymap(overrides?: Record<string, unknown>): Keymap {
	if (overrides == null || typeof overrides !== "object") {
		return { ...defaultKeymap };
	}

	const merged: Keymap = { ...defaultKeymap };

	for (const [chord, action] of Object.entries(overrides)) {
		const normalizedChord = chord.trim().toLowerCase();
		if (!normalizedChord) continue;

		// An explicit null/"" unbinds a default.
		if (action === null || action === "") {
			delete merged[normalizedChord];
			continue;
		}

		if (!isPanelAction(action)) {
			console.warn(
				`Ignoring keymap entry "${chord}": unknown action ${String(action)}`,
			);
			continue;
		}

		merged[normalizedChord] = action;
	}

	return merged;
}

export function lookupAction(
	keymap: Keymap,
	name: KeyName,
	modifiers: Modifiers,
): PanelAction | null {
	const chord = chordFromKey(name, modifiers);
	return keymap[chord] ?? keymap[name] ?? null;
}
