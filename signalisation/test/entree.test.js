import { describe, expect, it } from "vitest";
import { ESSAIS_CODE } from "../src/code.js";
import * as principal from "../src/index.js";
import { origineAdmise } from "../src/origine.js";
import { brancher, ouvrir, requete } from "./aide.js";

const ORIGINES = "https://w3cdotorg.github.io,http://localhost:*";

describe("origineAdmise", () => {
	it("admet les origines de la variable ORIGINES, localhost sur tout port", () => {
		for (const origine of ["https://w3cdotorg.github.io", "http://localhost", "http://localhost:8060", "http://localhost:65535"]) {
			expect(origineAdmise(origine, ORIGINES), origine).toBe(true);
		}
	});

	it("refuse le reste, l'origine absente comprise", () => {
		for (const origine of [
			null,
			"",
			"null",
			"https://w3cdotorg.github.io.exemple.net",
			"http://w3cdotorg.github.io",
			"https://w3cdotorg.github.io:443",
			"https://localhost:8060",
			"http://localhost.exemple.net",
			"http://localhost:8060.exemple.net",
			"http://localhost:",
			"http://localhost:abc",
			"http://localhost:123456",
		]) {
			expect(origineAdmise(origine, ORIGINES), String(origine)).toBe(false);
		}
		expect(origineAdmise("https://w3cdotorg.github.io", undefined)).toBe(false);
	});
});

const worker = principal.default;

describe("module principal", () => {
	it("n'exporte que des gestionnaires (workerd refuse de démarrer sinon)", () => {
		expect(Object.keys(principal).sort()).toEqual(["Salle", "default"]);
	});
});

describe("routes du Worker", () => {
	it("404 hors de /v1/creer et /v1/rejoindre/<code>", async () => {
		for (const chemin of ["/", "/v1", "/v1/creer/", "/v2/creer", "/v1/rejoindre"]) {
			const { reponse } = await ouvrir(chemin);
			expect(reponse.status, chemin).toBe(404);
		}
	});

	it("400 pour un code mal formé", async () => {
		for (const code of ["", "K7Q-2XM", "K7Q2X", "K7Q2XO", "K7Q2XM/plus"]) {
			const { reponse } = await ouvrir(`/v1/rejoindre/${code}`);
			expect(reponse.status, code).toBe(400);
		}
	});

	it("405 hors GET, 426 sans demande de WebSocket", async () => {
		// Sans Upgrade : workerd change en GET toute requête qui demande une WebSocket.
		expect((await ouvrir("/v1/creer", { methode: "POST", upgrade: null })).reponse.status).toBe(405);
		const { reponse } = await ouvrir("/v1/creer", { upgrade: null });
		expect(reponse.status).toBe(426);
		expect(reponse.headers.get("Upgrade")).toBe("websocket");
	});

	it("origine refusée : erreur origine puis fermeture, à la création comme à l'arrivée", async () => {
		for (const chemin of ["/v1/creer", "/v1/rejoindre/K7Q2XM"]) {
			for (const origine of [null, "https://exemple.net"]) {
				const socket = await ouvrir(chemin, { origine });
				expect(socket.reponse.status).toBe(101);
				expect(await socket.suivant()).toEqual({ t: "erreur", raison: "origine" });
				expect(await socket.fermeture).toMatchObject({ code: 1000 });
			}
		}
	});
});

describe("quota", () => {
	const envFactice = (salle) => ({
		ORIGINES,
		LIMITE_CREATION: { limit: async () => ({ success: true }) },
		SALLES: { idFromName: (code) => code, get: () => salle },
	});

	async function lireRefus(reponse) {
		expect(reponse.status).toBe(101);
		const socket = brancher(reponse.webSocket);
		return socket.suivant();
	}

	it("une salle qui ne répond pas (quota gratuit épuisé) : erreur quota", async () => {
		const env = envFactice({
			fetch: async () => {
				throw new Error("Exceeded allowed volume of requests in Durable Objects free tier.");
			},
		});
		expect(await lireRefus(await worker.fetch(requete("/v1/creer"), env))).toEqual({ t: "erreur", raison: "quota" });
		expect(await lireRefus(await worker.fetch(requete("/v1/rejoindre/K7Q2XM"), env))).toEqual({ t: "erreur", raison: "quota" });
	});

	it("un nouveau code tant que le code tiré a déjà un hôte, erreur quota au bout des essais", async () => {
		let appels = 0;
		const env = envFactice({
			fetch: async () => {
				appels++;
				return new Response(null, { status: 409 });
			},
		});
		expect(await lireRefus(await worker.fetch(requete("/v1/creer"), env))).toEqual({ t: "erreur", raison: "quota" });
		expect(appels).toBe(ESSAIS_CODE);
	});
});
