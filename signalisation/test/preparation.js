// Avant chaque test : l'API TURN de Cloudflare simulée par un espion de fetch (aucun appel réseau).
// La salle tourne dans le même isolat que les tests : l'espion la sert aussi. La réponse se fabrique
// à l'appel (une Response créée par le test ne se lit pas depuis un Durable Object).
import { afterEach, beforeEach, vi } from "vitest";
import { REPONSE_TURN } from "./turn.js";

beforeEach(() => {
	vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
		if (String(url).startsWith("https://rtc.live.cloudflare.com/")) return Response.json(REPONSE_TURN, { status: 201 });
		throw new Error(`appel réseau inattendu : ${url}`);
	});
});

afterEach(() => {
	vi.restoreAllMocks();
});
