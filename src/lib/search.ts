export type SearchEngine =
	| "google"
	| "bing"
	| "duckduckgo"
	| "perplexity"
	| "custom";

export const isValidCustomSearchEngineUrl = (url: string) => {
	if (url.trim() === "") return false;
	const searchPatternRegex =
		/^https?:\/\/(?:(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?|localhost|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+)?(\/[^\s?#]*)?\?[\w-]+=%s$/;
	return searchPatternRegex.test(url);
};

/**
 * Returns the URL to open for a web search, or null when the configuration is
 * invalid (only possible for the "custom" engine).
 */
export function buildSearchUrl(
	engine: SearchEngine,
	query: string,
	customSearchUrl: string,
): string | null {
	const encoded = encodeURI(query);

	switch (engine) {
		case "google":
			return `https://google.com/search?q=${encoded}`;
		case "duckduckgo":
			return `https://duckduckgo.com/?q=${encoded}`;
		case "bing":
			return `https://bing.com/search?q=${encoded}`;
		case "perplexity":
			return `https://perplexity.ai/search/new?q=${encoded}`;
		case "custom":
			if (!isValidCustomSearchEngineUrl(customSearchUrl)) {
				return null;
			}
			return customSearchUrl.replace("%s", encoded);
	}
}
