// Le test de bout en bout du jeu en ligne (spec §10) : l'export « Web pilote » servi sur
// http://localhost:8060 (l'origine que `npm run dev` admet, http://localhost:* ; pas 127.0.0.1), en IPv4
// seulement (une page chargée par ::1, Firefox ne trouve aucun candidat ICE dans un conteneur sans IPv6),
// la signalisation en local (`wrangler dev` sur ws://localhost:8787, la variante lelion/signalisation/url.pilote
// du réglage, que choisit l'export « Web pilote »), puis Chromium et Firefox (la manche à trois pages), WebKit (Copier le lien) et un
// mobile émulé par Chromium (un Android en paysage, au doigt, face à un hôte de bureau).
// L'export se fait avant : godot --headless --export-release "Web pilote" export/web-pilote/index.html.
import { defineConfig } from "@playwright/test";

export default defineConfig({
	testDir: ".",
	// Le contrôle de l'export publié et la partie sur la page déployée ont leurs propres configurations
	// (playwright.publie.config.js, playwright.en_direct.config.js).
	testIgnore: ["export_publie.spec.js", "en_direct.spec.js"],
	// Trois pages de 40 Mo de WebAssembly par test : un test à la fois.
	workers: 1,
	fullyParallel: false,
	retries: 0,
	// Un test : 1 min 30 à 1 min 50 mesurés pour le mobile bridé à 1,5 CPU (2 à 4 images par seconde) ; de la marge
	// pour une CI plus lente encore.
	timeout: 300_000,
	expect: { timeout: 30_000 },
	reporter: [["list"], ["html", { open: "never" }]],
	use: {
		baseURL: "http://localhost:8060",
		// Les textes du jeu en français (sa langue suit celle du navigateur).
		locale: "fr-FR",
		// Sans le film des captures : sous un rendu logiciel lent (la CI), il coûte cher aux pages.
		trace: { mode: "retain-on-failure", screenshots: false },
	},
	projects: [
		{ name: "chromium", grep: /@manche/, use: { browserName: "chromium" } },
		// Firefox sans affichage n'a pas de WebGL 2 (aucun pilote GL) : avec une fenêtre, sous Xvfb (xvfb-run).
		{ name: "firefox", grep: /@manche/, use: { browserName: "firefox", headless: false } },
		{ name: "webkit", grep: /@lien/, use: { browserName: "webkit" } },
		// Le mobile a son propre contexte (Pixel 7 en paysage) : le projet ne fixe que le navigateur.
		{ name: "mobile", grep: /@mobile/, use: { browserName: "chromium" } },
	],
	webServer: [
		{
			command: "python3 -m http.server 8060 --bind 127.0.0.1 --directory ../../export/web-pilote",
			url: "http://127.0.0.1:8060/index.html",
			stderr: "ignore",  // une ligne par fichier servi
			reuseExistingServer: false,
			timeout: 30_000,
		},
		{
			// Chaque lancement a une signalisation neuve : ses limites par IP (5 salles par minute) repartent de zéro.
			command: "npm --prefix ../../signalisation run dev -- --port 8787 --ip localhost",
			port: 8787,
			reuseExistingServer: false,
			timeout: 120_000,
			env: { WRANGLER_SEND_METRICS: "false" },
		},
	],
});
