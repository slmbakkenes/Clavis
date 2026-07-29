import type { PanelAction } from "lib/keymap";
import { solNative } from "lib/SolNative";
import { Clipboard, Linking } from "react-native";
import type { IRootStore } from "store";
import { ItemType, Widget } from "./ui.store";
import { formatTemporaryResultForClipboard } from "./ui.store.helpers";

export type ActionContext = {
	root: IRootStore;
	meta: boolean;
	shift: boolean;
	control: boolean;
	/** Sticky modifier state tracked across key events. */
	commandPressed: boolean;
};

export type ActionHandler = (ctx: ActionContext) => void | Promise<void>;

type WidgetActions = Partial<Record<PanelAction, ActionHandler>>;

function isImageClipboardPath(path: string | null | undefined) {
	if (!path) {
		return false;
	}
	const lower = path.toLowerCase();
	return (
		lower.endsWith(".png") ||
		lower.endsWith(".jpg") ||
		lower.endsWith(".jpeg") ||
		lower.endsWith(".tif") ||
		lower.endsWith(".tiff")
	);
}

/** Clamps selection to a list length, tolerating empty lists. */
const selectNextIn = (root: IRootStore, length: number) => {
	root.ui.selectedIndex = Math.min(
		Math.max(length - 1, 0),
		root.ui.selectedIndex + 1,
	);
};

const selectPrevious: ActionHandler = ({ root }) => {
	root.ui.selectedIndex = Math.max(0, root.ui.selectedIndex - 1);
};

/**
 * Fallbacks used when the focused widget doesn't implement an action.
 */
const globalActions: WidgetActions = {
	selectPrevious,
	dismiss: ({ root }) => {
		root.ui.setQuery("");
		root.ui.focusWidget(Widget.SEARCH);
	},
};

const searchActions: WidgetActions = {
	confirm: async ({ root, meta, shift, commandPressed }) => {
		if (!root.ui.query) {
			return;
		}

		root.ui.addToHistory(root.ui.query);

		if (shift) {
			root.ui.translateQuery();
			return;
		}

		// No matches, or an explicit ⌘⏎, means "search the web instead".
		if (!root.ui.searchItems.length || meta) {
			root.ui.openBrowserSearch();
			solNative.hideWindow();
			return;
		}

		const item = root.ui.searchItems[root.ui.selectedIndex];
		if (item == null) {
			return;
		}

		if (item.type === ItemType.TEMPORARY_RESULT && root.ui.temporaryResult) {
			Clipboard.setString(
				formatTemporaryResultForClipboard(root.ui.temporaryResult),
			);
			solNative.showToast("Copied to clipboard", "success");
			solNative.hideWindow();
			return;
		}

		root.ui.recordItemSelection(item);

		if (!item.preventClose) {
			solNative.hideWindow();
		}

		await root.ui.executeItem(item, { useMetaCallback: commandPressed });
	},
	dismiss: () => {
		solNative.hideWindow();
	},
	selectNext: ({ root }) => {
		// Bound against the rendered list, which excludes disabled items.
		selectNextIn(root, root.ui.searchItems.length);
	},
	selectPrevious: ({ root }) => {
		// At the top of the list, ↑ walks back through query history instead.
		if (root.ui.selectedIndex === 0 && root.ui.history.length > 0) {
			root.ui.setQuery(
				root.ui.history[root.ui.history.length - 1 - root.ui.historyPointer],
			);
			root.ui.setHistoryPointer(
				Math.min(root.ui.history.length, root.ui.historyPointer + 1),
			);
			return;
		}

		root.ui.selectedIndex = Math.max(0, root.ui.selectedIndex - 1);
	},
	deleteSelected: ({ root }) => {
		const item = root.ui.currentItem;
		if (item != null && item.type === ItemType.CUSTOM) {
			root.ui.deleteCustomItem(item.id);
		}
	},
	editSelected: ({ root }) => {
		const item = root.ui.currentItem;
		if (item != null && item.type === ItemType.CUSTOM) {
			root.ui.setEditingCustomItem(item);
			root.ui.focusWidget(Widget.CREATE_ITEM);
		}
	},
};

const fileSearchActions: WidgetActions = {
	confirm: ({ root, shift }) => {
		const file = root.ui.files[root.ui.selectedIndex];
		if (!file?.url) {
			return;
		}

		if (shift) {
			const directoryPath = file.url.substring(0, file.url.lastIndexOf("/"));
			solNative.openFinderAt(directoryPath);
			return;
		}

		solNative.openFile(file.url);
		solNative.hideWindow();
	},
	selectNext: ({ root }) => selectNextIn(root, root.ui.files.length),
};

const clipboardActions: WidgetActions = {
	confirm: ({ root, meta }) => {
		if (root.clipboard.clipboardItems.length === 0) {
			return;
		}

		const entry = root.clipboard.clipboardItems[root.ui.selectedIndex];
		const originalIndex = root.clipboard.clipboardItems.indexOf(entry);
		root.clipboard.popToTop(originalIndex);

		if (entry == null) {
			return;
		}

		if (meta) {
			try {
				Linking.openURL(entry.text);
			} catch (_e) {
				// Not a URL; nothing sensible to do.
			}
			solNative.hideWindow();
			return;
		}

		if (isImageClipboardPath(entry.url)) {
			solNative.pasteImageToFrontmostApp(entry.url as string);
		} else {
			solNative.pasteToFrontmostApp(entry.text);
		}
	},
	dismiss: () => {
		solNative.hideWindow();
	},
	selectNext: ({ root }) => selectNextIn(root, root.clipboard.items.length),
	deleteSelected: ({ root }) => {
		root.clipboard.deleteItem(root.ui.selectedIndex);
	},
};

const processesActions: WidgetActions = {
	confirm: ({ root }) => {
		const process = root.processes.filteredProcesses[root.ui.selectedIndex];
		if (process == null) {
			solNative.hideWindow();
			return;
		}

		solNative.killProcess(process.id.toString());
		solNative.hideWindow();
		solNative.showToast(`Process "${process.processName}" killed`, "success");
	},
	selectNext: ({ root }) =>
		selectNextIn(root, root.processes.filteredProcesses.length),
};

const translationActions: WidgetActions = {
	confirm: ({ root }) => {
		if (!root.ui.translationResults) {
			return;
		}

		Clipboard.setString(root.ui.translationResults[root.ui.selectedIndex]);
		solNative.hideWindow();
		root.ui.translationResults = [];
	},
	selectLeft: selectPrevious,
	selectPrevious,
	selectRight: ({ root }) => {
		const modulo = root.ui.thirdTranslationLanguage !== null ? 3 : 2;
		root.ui.selectedIndex = (root.ui.selectedIndex + 1) % modulo;
	},
	selectNext: ({ root }) => {
		const modulo = root.ui.thirdTranslationLanguage !== null ? 3 : 2;
		root.ui.selectedIndex = (root.ui.selectedIndex + 1) % modulo;
	},
};

const scratchpadActions: WidgetActions = {
	// The scratchpad is a text editor: Enter and the arrows belong to the input.
	confirm: () => {},
	selectNext: () => {},
	selectPrevious: () => {},
	dismiss: () => {
		solNative.hideWindow();
	},
	cycleScratchpadColor: ({ root }) => {
		root.ui.rotateScratchPadColor();
	},
};

const googleMapActions: WidgetActions = {
	dismiss: () => {
		solNative.hideWindow();
	},
};

export const widgetActions: Partial<Record<Widget, WidgetActions>> = {
	[Widget.SEARCH]: searchActions,
	[Widget.FILE_SEARCH]: fileSearchActions,
	[Widget.CLIPBOARD]: clipboardActions,
	[Widget.PROCESSES]: processesActions,
	[Widget.TRANSLATION]: translationActions,
	[Widget.SCRATCHPAD]: scratchpadActions,
	[Widget.GOOGLE_MAP]: googleMapActions,
};

export function resolveHandler(
	widget: Widget,
	action: PanelAction,
): ActionHandler | null {
	return widgetActions[widget]?.[action] ?? globalActions[action] ?? null;
}
