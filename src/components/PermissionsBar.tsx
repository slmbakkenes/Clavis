import { solNative } from "lib/SolNative";
import { observer } from "mobx-react-lite";
import type { FC } from "react";
import { Text, TouchableOpacity, View } from "react-native";
import { useStore } from "store";

export const PermissionsBar: FC = observer(() => {
	const store = useStore();

	if (store.ui.query) {
		return null;
	}

	// Accessibility is required by window management and paste-to-frontmost.
	if (!store.ui.isAccessibilityTrusted) {
		return (
			<TouchableOpacity
				onPress={() => {
					solNative.requestAccessibilityAccess();
					solNative.hideWindow();
				}}
			>
				<View className="subBg flex-row items-center justify-end gap-1 py-2 px-4">
					<Text className="text-xs darker-text mr-1">
						Window management needs Accessibility access — click to grant
					</Text>
				</View>
			</TouchableOpacity>
		);
	}

	return null;
});
