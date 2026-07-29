import { lookupAction } from "lib/keymap";
import { KEY_CODES, keyNameFromCode, MODIFIER_KEY_CODES } from "lib/keys";
import { solNative } from "lib/SolNative";
import { makeAutoObservable } from "mobx";
import type { EmitterSubscription } from "react-native";
import type { IRootStore } from "store";
import { type ActionContext, resolveHandler } from "./keystroke.actions";

let keyDownListener: EmitterSubscription | undefined;
let keyUpListener: EmitterSubscription | undefined;

export type KeystrokeStore = ReturnType<typeof createKeystrokeStore>;

type KeyEvent = {
	keyCode: number;
	meta: boolean;
	shift: boolean;
	control?: boolean;
};

/**
 * Translates key events into semantic actions (lib/keymap) and dispatches them
 * to the focused widget's handler table (keystroke.actions).
 *
 * Rebinding is data-driven: add a `keymap` object to
 * ~/.config/radix/config.json, e.g. {"control+n": "selectNext"}. Set a chord to
 * null to unbind a default.
 *
 * Note: this only covers keys the panel reacts to while open. Global hotkeys are
 * a separate mechanism (lib/shortcuts.tsx, registered natively).
 */
export const createKeystrokeStore = (root: IRootStore) => {
	const store = makeAutoObservable({
		commandPressed: false,
		shiftPressed: false,
		controlPressed: false,

		simulateEnter: () => {
			store.keyDown({ keyCode: KEY_CODES.enter, meta: false, shift: false });
		},

		keyDown: async ({ keyCode, meta, shift, control }: KeyEvent) => {
			if (MODIFIER_KEY_CODES.has(keyCode)) {
				if (keyCode === KEY_CODES.command) store.commandPressed = true;
				if (keyCode === KEY_CODES.shift) store.shiftPressed = true;
				if (keyCode === KEY_CODES.control) store.controlPressed = true;
				return;
			}

			const name = keyNameFromCode(keyCode);
			if (name == null) {
				return;
			}

			const modifiers = {
				meta,
				shift: shift || store.shiftPressed,
				control: control ?? store.controlPressed,
			};

			// The confirm dialog is modal and outranks the focused widget.
			if (root.ui.confirmDialogShown) {
				if (keyCode === KEY_CODES.enter) {
					root.ui.executeConfirmCallback();
				} else if (keyCode === KEY_CODES.escape) {
					root.ui.closeConfirm();
				}
				return;
			}

			const action = lookupAction(root.ui.keymap, name, modifiers);
			if (action == null) {
				return;
			}

			if (action === "confirm") {
				root.ui.setHistoryPointer(0);
			}

			const handler = resolveHandler(root.ui.focusedWidget, action);
			if (handler == null) {
				return;
			}

			const ctx: ActionContext = {
				root,
				meta: modifiers.meta,
				shift: modifiers.shift,
				control: modifiers.control,
				commandPressed: store.commandPressed,
			};

			await handler(ctx);
		},

		keyUp: async ({ keyCode }: { keyCode: number }) => {
			if (keyCode === KEY_CODES.command) store.commandPressed = false;
			if (keyCode === KEY_CODES.shift) store.shiftPressed = false;
			if (keyCode === KEY_CODES.control) store.controlPressed = false;
		},

		cleanUp: () => {
			keyDownListener?.remove();
			keyUpListener?.remove();
		},
	});

	keyDownListener = solNative.addListener("keyDown", store.keyDown);
	keyUpListener = solNative.addListener("keyUp", store.keyUp);

	return store;
};
