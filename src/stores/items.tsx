import { Assets } from "assets";
import Chance from "chance";
import { FileIcon } from "components/FileIcon";
import { solNative } from "lib/SolNative";
import { nanoid } from "nanoid";
import { Clipboard, Linking } from "react-native";
import type { IRootStore } from "store";
import { v4 as uuidv4 } from "uuid";
import { systemPreferenceItems } from "./systemPreferences";
import { ItemType, Widget } from "./ui.store";

const chance = new Chance();

export function createBaseItems(store: IRootStore) {
	const items: Item[] = [
		{
			id: "toggle_appearance",
			symbol: "circle.lefthalf.filled",
			name: "Toggle system appearance",
			alias: "dark",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.toggleDarkMode();
			},
		},
		{
			id: "sleep",
			symbol: "moon.zzz.fill",
			name: "Sleep",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				try {
					await solNative.executeAppleScript(
						'tell application "Finder" to sleep',
					);
				} catch (e) {
					solNative.showToast(`Could not sleep: ${e}`, "error");
				}
			},
		},
		{
			id: "restart",
			symbol: "arrow.clockwise",
			name: "Restart",
			preventClose: true,
			type: ItemType.CONFIGURATION,
			callback: async () => {
				store.ui.confirm("Restart Computer", async () => {
					try {
						await solNative.executeAppleScript(
							'tell application "Finder" to restart',
						);
						solNative.showToast("Restarting", "success");
					} catch (e) {
						solNative.showToast(`Could not restart: ${e}`, "error");
					}
				});
			},
		},
		{
			id: "shut_down",
			symbol: "power",
			name: "Shut Down",
			type: ItemType.CONFIGURATION,
			preventClose: true,
			callback: async () => {
				try {
					store.ui.confirm("Shut Down", async () => {
						await solNative.executeAppleScript(
							'tell application "Finder" to shut down',
						);
						solNative.showToast("Shutting down", "success");
					});
				} catch (e) {
					solNative.showToast(`Could not power off: ${e}`, "error");
				}
			},
		},
		{
			id: "airdrop",
			symbol: "dot.radiowaves.up.forward",
			name: "AirDrop",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.executeAppleScript(`tell application "Finder"
          if exists window "AirDrop" then
                  tell application "System Events" to ¬
                          tell application process "Finder" to ¬
                                  perform action "AXRaise" of ¬
                                          (windows whose title is "AirDrop")
          else if (count Finder windows) > 0 then
                  make new Finder window
                  tell application "System Events" to ¬
                          click menu item "AirDrop" of menu 1 of menu bar item ¬
                                  "Go" of menu bar 1 of application process "Finder"
          else
                  tell application "System Events" to ¬
                          click menu item "AirDrop" of menu 1 of menu bar item ¬
                                  "Go" of menu bar 1 of application process "Finder"
          end if
          activate
        end tell`);
			},
		},
		{
			id: "lock",
			symbol: "lock.fill",
			name: "Lock",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				try {
					await solNative.executeAppleScript(
						`tell application "System Events" to keystroke "q" using {control down, command down}`,
					);
				} catch (e) {
					solNative.showToast(`Could not lock: ${e}`, "error");
				}
			},
		},
		{
			id: "settings",
			symbol: "gearshape.fill",
			name: "Radix Settings",
			alias: "preferences",
			type: ItemType.CONFIGURATION,
			callback: () => {
				store.ui.showSettings();
			},
			preventClose: true,
		},
		{
			id: "grant_accessibility_access",
			symbol: "accessibility",
			name: "Grant Accessibility Access",
			alias: "permission",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.requestAccessibilityAccess();
			},
		},
		{
			id: "open_full_disk_access_settings",
			symbol: "lock.shield.fill",
			name: "Open Full Disk Access Settings",
			alias: "permission",
			type: ItemType.CONFIGURATION,
			callback: () => {
				Linking.openURL(
					"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
				).catch((e) => {
					solNative.showToast(
						`Could not open Full Disk Access settings: ${e}`,
						"error",
					);
				});
			},
		},
		{
			id: "create_shorcut",
			symbol: "link",
			name: "Create Quick Link",
			type: ItemType.CONFIGURATION,
			callback: () => {
				store.ui.focusWidget(Widget.CREATE_ITEM);
			},
			preventClose: true,
		},
		{
			id: "resize_fullscreen",
			symbol: "arrow.up.left.and.arrow.down.right",
			name: "Resize window to full-screen",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeFrontmostFullscreen();
			},
		},
		{
			id: "resize_right_half",
			symbol: "rectangle.righthalf.inset.filled",
			name: "Resize window to right-half",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeFrontmostRightHalf();
			},
		},
		{
			id: "resize_left_half",
			symbol: "rectangle.lefthalf.inset.filled",
			name: "Resize window to left-half",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeFrontmostLeftHalf();
			},
		},
		{
			id: "resize_top_half",
			symbol: "rectangle.tophalf.inset.filled",
			name: "Resize window to top-half",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeFrontmostTopHalf();
			},
		},
		{
			id: "resize_bottom_half",
			symbol: "rectangle.bottomhalf.inset.filled",
			name: "Resize window to bottom-half",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeFrontmostBottomHalf();
			},
		},
		{
			id: "resize_top_left",
			symbol: "rectangle.inset.topleft.filled",
			name: "Resize window to top-left",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeTopLeft();
			},
		},
		{
			id: "resize_top_right",
			symbol: "rectangle.inset.topright.filled",
			name: "Resize window to top-right",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeTopRight();
			},
		},
		{
			id: "resize_bottom_left",
			symbol: "rectangle.inset.bottomleft.filled",
			name: "Resize window to bottom-left",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeBottomLeft();
			},
		},
		{
			id: "resize_bottom_right",
			symbol: "rectangle.inset.bottomright.filled",
			name: "Resize window to bottom-right",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeBottomRight();
			},
		},
		{
			id: "resize_left_third",
			symbol: "rectangle.leadingthird.inset.filled",
			name: "Resize window to left third",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeLeftThird();
			},
		},
		{
			id: "resize_center_third",
			symbol: "rectangle.split.3x1",
			name: "Resize window to center third",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeCenterThird();
			},
		},
		{
			id: "resize_right_third",
			symbol: "rectangle.trailingthird.inset.filled",
			name: "Resize window to right third",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeRightThird();
			},
		},
		{
			id: "resize_left_two_thirds",
			symbol: "rectangle.lefthalf.inset.filled.arrow.left",
			name: "Resize window to left two-thirds",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeLeftTwoThirds();
			},
		},
		{
			id: "resize_right_two_thirds",
			symbol: "rectangle.righthalf.inset.filled.arrow.right",
			name: "Resize window to right two-thirds",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.resizeRightTwoThirds();
			},
		},
		{
			id: "move_next_screen",
			symbol: "arrow.right.to.line",
			name: "Move window to next screen",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.moveFrontmostNextScreen();
			},
		},
		{
			id: "move_previous_screen",
			symbol: "arrow.left.to.line",
			name: "Move window to previous screen",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.moveFrontmostPrevScreen();
			},
		},
		{
			id: "move_to_previous_space",
			symbol: "arrow.left.square",
			name: "Move window to previous space",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.moveFrontmostToPreviousSpace();
			},
		},
		{
			id: "move_to_next_space",
			symbol: "arrow.right.square",
			name: "Move window to next space",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.moveFrontmostToNextSpace();
			},
		},
		{
			id: "move_center",
			symbol: "rectangle.center.inset.filled",
			name: "Move window to center",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.moveFrontmostCenter();
			},
		},
		{
			id: "scratchpad",
			symbol: "note.text",
			name: "Scratchpad",
			preventClose: true,
			type: ItemType.CONFIGURATION,
			callback: () => {
				store.ui.showScratchpad();
			},
		},
		{
			id: "clipboard_manager",
			symbol: "clipboard",
			name: "Clipboard Manager",
			type: ItemType.CONFIGURATION,
			callback: () => {
				store.ui.showClipboardManager();
			},
			preventClose: true,
		},
		{
			id: "process_manager",
			symbol: "xmark.octagon",
			name: "Kill process",
			type: ItemType.CONFIGURATION,
			callback: () => {
				store.ui.showProcessManager();
			},
			preventClose: true,
		},
		{
			id: "file_search",
			symbol: "magnifyingglass",
			name: "File Search",
			type: ItemType.CONFIGURATION,
			callback: () => {
				store.ui.showFileSearch();
			},
			preventClose: true,
		},
		{
			id: "downloads_folder",
			IconComponent: (...props: any[]) => (
				<FileIcon {...props} url="~/Downloads" className="w-6 h-6" />
			),
			name: "Downloads",
			type: ItemType.CONFIGURATION,
			callback: () => {
				Linking.openURL("~/Downloads");
			},
		},
		{
			id: "desktop_folder",
			IconComponent: (...props: any[]) => {
				return <FileIcon {...props} url="~/Desktop" className="w-6 h-6" />;
			},
			type: ItemType.CONFIGURATION,
			name: "Desktop",
			callback: () => {
				Linking.openURL("~/Desktop");
			},
		},
		{
			id: "applications_folder",
			IconComponent: (...props: any[]) => (
				<FileIcon {...props} url="/Applications" className="w-6 h-6" />
			),
			name: "Applications",
			alias: "application",
			type: ItemType.CONFIGURATION,
			callback: () => {
				Linking.openURL("/Applications");
			},
		},
		{
			id: "pictures_folder",
			IconComponent: (...props: any[]) => (
				<FileIcon {...props} url="~/Pictures" className="w-6 h-6" />
			),
			name: "Pictures",
			type: ItemType.CONFIGURATION,
			callback: () => {
				Linking.openURL("~/Pictures");
			},
		},
		{
			id: "developer_folder",
			IconComponent: (...props: any[]) => (
				<FileIcon {...props} url="~/Developer" className="w-6 h-6" />
			),
			name: "Developer",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				try {
					await Linking.openURL("~/Developer");
				} catch (e) {
					solNative.showToast(
						"Developer folder not found, try creating ~/Developer 😉",
						"error",
					);
				}
			},
		},
		{
			id: "documents_folder",
			IconComponent: (...props: any[]) => (
				<FileIcon {...props} url="~/Documents" className="w-6 h-6" />
			),
			name: "Documents",
			type: ItemType.CONFIGURATION,
			callback: () => {
				Linking.openURL("~/Documents");
			},
		},
		{
			id: "start_google_meet",
			iconImage: Assets.googleLogo,
			name: "Start Google Meet",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				await Linking.openURL(`https://meet.google.com/new`);

				solNative.executeAppleScript(`if application "Safari" is running then
          delay 3
          tell application "Safari"
            set myurl to URL of front document as string
          end tell

          set baseUrl to "https://meet.google.com/new"

          if (myurl contains baseUrl) then
            delay 3
            tell application "Safari"
              set myurl to URL of front document as string
            end tell
          else
            set the clipboard to myurl as string
            display notification "Google Meet link copied to clipboard" with title "Link Copied" sound name "Frog"
            return
          end if

          if (myurl contains baseUrl) then
            delay 3
            tell application "Safari"
              set myurl to URL of front document as string
            end tell
          else
            set the clipboard to myurl as string
            display notification "Google Meet link copied to clipboard" with title "Link Copied" sound name "Frog"
            return
          end if

          if (myurl contains baseUrl) then
            delay 3
            tell application "Safari"
              set myurl to URL of front document as string
            end tell
          else
            set the clipboard to myurl as string
            display notification "Google Meet link copied to clipboard" with title "Link Copied" sound name "Frog"
            return
          end if
          
          if (myurl contains baseUrl) then
            display notification "Google Meet could not be copied" with title "Couldn't copy Google Meet link" sound name "Frog"
          else
            set the clipboard to myurl as string
            display notification "Google Meet link copied to clipboard" with title "Link Copied" sound name "Frog"
          end if
        end if
        `);
			},
		},
		{
			id: "generate_nano_id",
			symbol: "number",
			name: "Generate Nano ID",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				const id = nanoid();
				solNative.pasteToFrontmostApp(id);
				solNative.showToast("Generated and pasted", "success");
			},
		},
		{
			id: "generate_uuid",
			symbol: "number.square",
			name: "Generate UUID",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				const id = uuidv4();
				solNative.pasteToFrontmostApp(id);
				solNative.showToast("Generated and pasted", "success");
			},
		},
		{
			id: "generate_lorem_ipsum",
			symbol: "text.alignleft",
			name: "Generate Lorem Ipsum",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				const paragraph = chance.paragraph();
				solNative.pasteToFrontmostApp(paragraph);
				solNative.showToast("Generated", "success");
			},
		},
		{
			id: "quit_sol",
			symbol: "xmark.circle.fill",
			name: "Quit/Exit Radix",
			alias: "exit",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				solNative.quit();
			},
		},
		{
			id: "paste_as_json",
			symbol: "curlybraces",
			name: "Paste as JSON",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				let latestString = await Clipboard.getString();
				if (latestString)
					try {
						latestString = JSON.parse(latestString);
						solNative.pasteToFrontmostApp(
							JSON.stringify(latestString, null, 2),
						);
						solNative.showToast("Pasted!", "success");
					} catch (e) {
						solNative.pasteToFrontmostApp(latestString);
						solNative.showToast("Not a valid JSON", "error");
					}
			},
		},
		{
			id: "kill_all_apps",
			symbol: "xmark.app",
			name: "Kill all apps",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				try {
					solNative.executeAppleScript(`-- get list of open apps
          tell application "System Events"
            set allApps to displayed name of (every process whose background only is false) as list
          end tell
          
          -- leave some apps open 
          set exclusions to {"AppleScript Editor", "Automator", "Finder", "LaunchBar"}
          
          -- quit each app
          repeat with thisApp in allApps
            set thisApp to thisApp as text
            if thisApp is not in exclusions then
              tell application thisApp to quit
            end if
          end repeat
          `);
				} catch (e) {
					solNative.showToast(
						`Could not kill all apps: ${e}. Be sure to give accessibility access`,
						"error",
					);
				}
			},
		},
		...systemPreferenceItems,
		{
			id: "copy_wifi_password",
			symbol: "key.fill",
			name: "Copy Wi-Fi Password to Clipboard",
			type: ItemType.CONFIGURATION,
			alias: "wifi",
			callback: () => {
				try {
					const res = solNative.getWifiPassword();
					if (!res) {
						solNative.showToast(`No password found`, "error");
						return;
					}
					Clipboard.setString(res.password);
					solNative.showToast("Password copied to clipboard", "success");
				} catch (e) {
					solNative.showToast(`Could not retrieve password: ${e}`, "error");
				}
			},
		},
		{
			id: "reveal_wifi_password",
			symbol: "qrcode",
			name: "Reveal Wi-Fi Password",
			type: ItemType.CONFIGURATION,
			alias: "wifi",
			callback: () => {
				try {
					const res = solNative.getWifiPassword();
					if (!res) {
						solNative.showToast(`Could not retrieve password`, "success");
						return;
					}

					Clipboard.setString(res.password);
					solNative.showWifiQR(res.ssid, res.password);
				} catch (e) {
					solNative.showToast(`Could not retrieve password: ${e}`, "error");
				}
			},
		},
		{
			id: "empty_trash",
			symbol: "trash.fill",
			name: "Empty Trash",
			type: ItemType.CONFIGURATION,
			preventClose: true,
			alias: "trash",
			callback: async () => {
				store.ui.confirm("Clear Trash", async () => {
					try {
						await solNative.executeAppleScript(
							`tell application "Finder" to empty trash`,
						);
						solNative.showToast("Trash emptied", "success");
					} catch (e) {
						solNative.showToast(`Could not empty trash: ${e}`, "error");
					}
				});
			},
		},
		{
			id: "hide_notch",
			symbol: "rectangle.topthird.inset.filled",
			name: "Hide/Restore Notch",
			type: ItemType.CONFIGURATION,
			callback: async () => {
				try {
					await solNative.hideNotch();
					solNative.showToast("Notch hidden", "success");
				} catch (e) {
					solNative.showToast(`Could not hide notch: ${e}`, "error");
				}
			},
		},
		// {
		//   icon: '⌨️',
		//   name: 'Add VSCode bindings to Xcode',
		//   type: ItemType.CONFIGURATION,
		//   callback: async () => {
		//     await solNative.executeBashScript(
		//       `touch ~/Library/Developer/Xcode/UserData/KeyBindings/VSCodeKeyBindings.idekeybindings`,
		//     )

		//     solNative.showToast('✅ Added bindings. Select them from the Xcode preferences')
		//   },
		// }
	];

	if (__DEV__) {
		items.push({
			id: "sucess_toast",
			symbol: "checkmark.circle",
			name: "Success toast",
			type: ItemType.CONFIGURATION,
			preventClose: true,
			callback: () => {
				solNative.showToast(
					"This is a Toast test with a long test to make sure everything fits! 🍞",
					"success",
				);
			},
		});
		items.push({
			id: "error_toast",
			symbol: "exclamationmark.triangle",
			name: "error toast",
			type: ItemType.CONFIGURATION,
			callback: () => {
				solNative.showToast(
					"This is a Toast test with a long test to make sure everything fits! 🍞",
					"error",
				);
			},
		});
	}

	return items;
}
