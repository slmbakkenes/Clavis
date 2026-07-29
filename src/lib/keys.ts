/**
 * macOS virtual key codes for the keys Radix handles in-panel.
 *
 * These are *not* the global hotkeys (those live in lib/shortcuts.tsx and are
 * registered natively); these are the keys the panel itself reacts to while
 * it is open.
 */
export const KEY_CODES = {
	// Navigation / editing
	enter: 36,
	escape: 53,
	tab: 48,
	delete: 51,
	forwarddelete: 117,
	space: 49,
	left: 123,
	right: 124,
	up: 126,
	down: 125,
	home: 115,
	end: 119,
	pageup: 116,
	pagedown: 121,
	// Letters
	a: 0,
	b: 11,
	c: 8,
	d: 2,
	e: 14,
	f: 3,
	g: 5,
	h: 4,
	i: 34,
	j: 38,
	k: 40,
	l: 37,
	m: 46,
	n: 45,
	o: 31,
	p: 35,
	q: 12,
	r: 15,
	s: 1,
	t: 17,
	u: 32,
	v: 9,
	w: 13,
	x: 7,
	y: 16,
	z: 6,
	// Digits
	"0": 29,
	"1": 18,
	"2": 19,
	"3": 20,
	"4": 21,
	"5": 23,
	"6": 22,
	"7": 26,
	"8": 28,
	"9": 25,
	// Modifiers
	command: 55,
	shift: 60,
	control: 59,
} as const;

export type KeyName = keyof typeof KEY_CODES;

/** Key codes that only set modifier state and never resolve to an action. */
export const MODIFIER_KEY_CODES: ReadonlySet<number> = new Set([
	KEY_CODES.command,
	KEY_CODES.shift,
	KEY_CODES.control,
]);

const CODE_TO_NAME: Record<number, KeyName> = Object.fromEntries(
	Object.entries(KEY_CODES).map(([name, code]) => [code, name as KeyName]),
) as Record<number, KeyName>;

export function keyNameFromCode(keyCode: number): KeyName | null {
	return CODE_TO_NAME[keyCode] ?? null;
}

export type Modifiers = {
	meta: boolean;
	shift: boolean;
	control: boolean;
};

/**
 * Serializes a key press into a chord string like "shift+enter" or
 * "control+j". Modifier order is fixed so lookups are stable.
 */
export function chordFromKey(name: KeyName, modifiers: Modifiers): string {
	const parts: string[] = [];
	if (modifiers.control) parts.push("control");
	if (modifiers.meta) parts.push("command");
	if (modifiers.shift) parts.push("shift");
	parts.push(name);
	return parts.join("+");
}
