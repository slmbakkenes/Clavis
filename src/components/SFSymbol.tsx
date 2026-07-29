import { cssInterop } from "nativewind";
import { requireNativeComponent, type ViewStyle } from "react-native";

export type SFSymbolWeight =
	| "ultraLight"
	| "thin"
	| "light"
	| "regular"
	| "medium"
	| "semibold"
	| "bold"
	| "heavy"
	| "black";

type SFSymbolProps = {
	/** SF Symbol name, e.g. "magnifyingglass". Unknown names render empty. */
	name: string;
	/** Point size, defaults to 16 on the native side. */
	size?: number;
	weight?: SFSymbolWeight;
	/** Hex colour. Omit to follow the system label colour. */
	color?: string;
	style?: ViewStyle;
	className?: string;
};

const SFSymbolNative = requireNativeComponent<SFSymbolProps>("SFSymbol");

export const SFSymbol = (props: SFSymbolProps) => {
	return <SFSymbolNative {...props} />;
};

cssInterop(SFSymbol, {
	className: "style",
});
