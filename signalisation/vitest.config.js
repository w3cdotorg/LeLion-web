import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
	plugins: [
		cloudflareTest({
			wrangler: { configPath: "./wrangler.jsonc" },
			// De faux secrets TURN : l'API est simulée par test/preparation.js, jamais appelée pour de vrai.
			miniflare: { bindings: { TURN_KEY_ID: "cle-turn-de-test", TURN_KEY_API_TOKEN: "jeton-turn-de-test" } },
		}),
	],
	test: { setupFiles: ["./test/preparation.js"] },
});
