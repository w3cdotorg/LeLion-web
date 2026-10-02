// La partie de contrôle sur la page déployée (phase 5) : deux pages Chromium, un hôte qui crée par le clavier,
// un invité qui rejoint par le lien, reliés en WebRTC par le Worker de la page. LELION_PAGE : l'adresse de la
// page (par défaut celle de GitHub Pages). Rien n'est servi ni lancé ici : la page et son Worker existent déjà.
import { defineConfig } from "@playwright/test";

export default defineConfig({
	testDir: ".",
	testMatch: "en_direct.spec.js",
	workers: 1,
	retries: 0,
	timeout: 180_000,
	reporter: [["list"]],
	use: { baseURL: process.env.LELION_PAGE ?? "https://w3cdotorg.github.io/LeLion-web/", locale: "fr-FR", browserName: "chromium" },
});
