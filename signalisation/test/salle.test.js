import { describe, expect, it, vi } from "vitest";
import { arriver, creerSalle, ouvrir } from "./aide.js";
import { ICE_ATTENDU } from "./turn.js";

const FORME_CODE = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;

describe("création", () => {
	it("l'hôte reçoit salle : un code, l'id 1 et ses serveurs ICE (TURN compris)", async () => {
		const { salle } = await creerSalle();
		expect(salle).toEqual({ t: "salle", code: expect.stringMatching(FORME_CODE), id: 1, ice: ICE_ATTENDU });
	});

	it("deux salles n'ont pas le même code", async () => {
		const a = await creerSalle();
		const b = await creerSalle();
		expect(a.code).not.toBe(b.code);
	});
});

describe("arrivée", () => {
	it("le client reçoit bienvenue, l'hôte arrivee : même id, mêmes identifiants neufs, un appel TURN", async () => {
		const { hote, code } = await creerSalle();
		const appelsAvant = fetch.mock.calls.length;
		const { bienvenue, arrivee } = await arriver(hote, code);
		expect(bienvenue).toEqual({ t: "bienvenue", id: expect.any(Number), ice: ICE_ATTENDU });
		expect(arrivee).toEqual({ t: "arrivee", id: bienvenue.id, ice: ICE_ATTENDU });
		expect(fetch.mock.calls.length - appelsAvant).toBe(1);
	});

	it("des identifiants de pair entiers dans 2..2³¹-1, distincts dans la salle", async () => {
		const { hote, code } = await creerSalle();
		const ids = new Set();
		for (let i = 0; i < 6; i++) {
			const { id, client } = await arriver(hote, code);
			expect(Number.isInteger(id) && id >= 2 && id <= 2 ** 31 - 1, String(id)).toBe(true);
			ids.add(id);
			client.fermer();
			expect(await hote.suivant()).toEqual({ t: "depart", id });
		}
		expect(ids.size).toBe(6);
	});

	it("ni 0, ni 1, ni un id déjà donné dans la salle (même à un client parti)", async () => {
		const { hote, code } = await creerSalle();
		const hasard = crypto.getRandomValues.bind(crypto);
		const tirages = [0, 1, 5, 5, 0x80000005, 7];
		vi.spyOn(crypto, "getRandomValues").mockImplementation((tableau) => {
			if (!(tableau instanceof Uint32Array) || tirages.length === 0) return hasard(tableau);
			tableau[0] = tirages.shift();
			return tableau;
		});
		const premier = await arriver(hote, code);
		expect(premier.id).toBe(5);
		premier.client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id: 5 });
		expect((await arriver(hote, code)).id).toBe(7);
		expect(tirages).toEqual([]);
	});

	it("le code s'accepte en minuscules", async () => {
		const { hote, code } = await creerSalle();
		const { bienvenue } = await arriver(hote, code.toLowerCase());
		expect(bienvenue.t).toBe("bienvenue");
	});

	it("code inconnu : erreur inconnue puis fermeture", async () => {
		const client = await ouvrir("/v1/rejoindre/ZZZZZZ");
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
		expect(await client.fermeture).toMatchObject({ code: 1000 });
	});
});

describe("départs", () => {
	it("un client parti avant ouvert : depart chez l'hôte", async () => {
		const { hote, code } = await creerSalle();
		const { client, id } = await arriver(hote, code);
		client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id });
	});

	it("l'hôte parti : la salle est supprimée, les arrivants en cours reçoivent erreur inconnue", async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		hote.fermer();
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
		expect(await client.fermeture).toMatchObject({ code: 1000 });
		const tard = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await tard.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
	});
});

describe("battement", () => {
	it('{"t":"ping"} reçoit {"t":"pong"}, chez l\'hôte comme chez un client', async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		hote.envoyer('{"t":"ping"}');
		expect(await hote.suivant()).toEqual({ t: "pong" });
		client.envoyer('{"t":"ping"}');
		expect(await client.suivant()).toEqual({ t: "pong" });
	});
});
