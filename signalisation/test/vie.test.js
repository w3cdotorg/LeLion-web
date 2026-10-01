import { evictDurableObject, runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { arriver, creerSalle, ouvrir, salleDe } from "./aide.js";

const QUATRE_HEURES = 4 * 60 * 60 * 1000;

/** L'alarme de la salle `code` et le nombre de ses tables SQLite à nous (`pairs`). */
async function etat(code) {
	return runInDurableObject(salleDe(code), async (_salle, ctx) => ({
		alarme: await ctx.storage.getAlarm(),
		tables: ctx.storage.sql.exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pairs'").toArray().length,
	}));
}

describe("expiration à 4 h", () => {
	it("la création pose l'alarme à 4 h", async () => {
		const avant = Date.now();
		const { code } = await creerSalle();
		const { alarme } = await etat(code);
		expect(alarme).toBeGreaterThanOrEqual(avant + QUATRE_HEURES);
		expect(alarme).toBeLessThanOrEqual(Date.now() + QUATRE_HEURES);
	});

	it("l'alarme ferme la salle : erreur expiree à tous, stockage effacé, plus d'arrivée", async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect(await hote.suivant()).toEqual({ t: "erreur", raison: "expiree" });
		expect(await hote.fermeture).toEqual({ code: 1000, raison: "expiree" });
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "expiree" });
		expect(await etat(code)).toEqual({ alarme: null, tables: 0 });
		const tard = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await tard.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
	});

	it("l'hôte parti efface l'alarme et le stockage", async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		hote.fermer();
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
		await expect.poll(() => etat(code)).toEqual({ alarme: null, tables: 0 });
	});
});

describe("hibernation", () => {
	it("évincée de la mémoire, la salle garde ses membres, leurs ids et le relais", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		await evictDurableObject(salleDe(code));
		hote.envoyer({ t: "offre", vers: a.id, sdp: "v=0" });
		expect(await a.client.suivant()).toEqual({ t: "offre", de: 1, sdp: "v=0" });
		a.client.envoyer({ t: "reponse", vers: 1, sdp: "v=0" });
		expect(await hote.suivant()).toEqual({ t: "reponse", de: a.id, sdp: "v=0" });
		hote.envoyer('{"t":"ping"}');
		expect(await hote.suivant()).toEqual({ t: "pong" });
		const b = await arriver(hote, code);
		expect(b.id).not.toBe(a.id);
		a.client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id: a.id });
	});
});
