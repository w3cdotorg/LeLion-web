import { describe, expect, it, vi } from "vitest";
import { API_TURN, DUREE_TURN_S, STUN, fabriquerIce } from "../src/ice.js";
import { ICE_ATTENDU } from "./turn.js";

const SECRETS = { TURN_KEY_ID: "cle/42", TURN_KEY_API_TOKEN: "jeton" };

describe("fabriquerIce", () => {
	it("sans secrets TURN (développement local) : STUN seul, aucun appel", async () => {
		expect(await fabriquerIce({})).toEqual([{ urls: STUN }]);
		expect(await fabriquerIce({ TURN_KEY_ID: "cle" })).toEqual([{ urls: STUN }]);
		expect(fetch).not.toHaveBeenCalled();
	});

	it("avec les secrets : un POST à l'API TURN, identifiants de 2 h, port 53 retiré", async () => {
		expect(await fabriquerIce(SECRETS)).toEqual(ICE_ATTENDU);
		expect(fetch).toHaveBeenCalledTimes(1);
		const [url, init] = vi.mocked(fetch).mock.calls[0];
		expect(url).toBe(`${API_TURN}/cle%2F42/credentials/generate-ice-servers`);
		expect(init.method).toBe("POST");
		expect(init.headers).toEqual({ Authorization: "Bearer jeton", "Content-Type": "application/json" });
		expect(JSON.parse(init.body)).toEqual({ ttl: DUREE_TURN_S });
		expect(DUREE_TURN_S).toBe(7200);
		expect(init.signal).toBeInstanceOf(AbortSignal);
	});

	it("API en erreur, injoignable ou réponse étrange : STUN seul", async () => {
		const reponses = [
			async () => new Response("non", { status: 401 }),
			async () => {
				throw new Error("réseau coupé");
			},
			async () => Response.json({ rien: true }, { status: 201 }),
			async () => Response.json({ iceServers: [{ urls: ["turn:turn.cloudflare.com:53"], username: "u", credential: "c" }] }, { status: 201 }),
			async () => Response.json({ iceServers: [{ urls: ["turn:x"], username: 1, credential: "c" }] }, { status: 201 }),
		];
		for (const reponse of reponses) {
			vi.mocked(fetch).mockImplementationOnce(reponse);
			expect(await fabriquerIce(SECRETS)).toEqual([{ urls: STUN }]);
		}
	});

	it("ne garde que urls, username et credential d'un serveur TURN", async () => {
		vi.mocked(fetch).mockImplementationOnce(async () =>
			Response.json({ iceServers: [{ urls: ["turn:a:3478"], username: "u", credential: "c", autre: "x" }] }, { status: 201 }),
		);
		expect(await fabriquerIce(SECRETS)).toEqual([{ urls: STUN }, { urls: ["turn:a:3478"], username: "u", credential: "c" }]);
	});
});
