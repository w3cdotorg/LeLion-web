// Le contrôle de l'export publié (phase 5, spec §11) : l'export « Web » (export/web, celui que Pages publie),
// servi sur http://localhost:8061, dans Chromium. Rien du test de bout en bout : ni pilote, ni wrangler dev.
// Par défaut, la signalisation est simulée par la page (routeWebSocket : aucun réseau) ; avec
// SIGNALISATION_EN_DIRECT=1 (le job de déploiement, le Worker venant d'être déployé), la page parle au vrai
// Worker, qui refuse son origine (http://localhost:8061 n'est pas la page publiée).
// L'export se fait avant : godot --headless --export-release Web export/web/index.html.
import { defineConfig } from "@playwright/test";

export default defineConfig({
	testDir: ".",
	testMatch: "export_publie.spec.js",
	workers: 1,
	retries: 0,
	timeout: 120_000,
	reporter: [["list"]],
	use: { baseURL: "http://localhost:8061", locale: "fr-FR", browserName: "chromium" },
	webServer: {
		command: "python3 -m http.server 8061 --bind 127.0.0.1 --directory ../../export/web",
		url: "http://127.0.0.1:8061/index.html",
		stderr: "ignore",
		reuseExistingServer: false,
		timeout: 30_000,
	},
});
