import { evictDurableObject, runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { describe, expect, it, vi } from "vitest";
import { LIMITES } from "../src/protocole.js";
import { arriver, creerSalle, ouvrir, salleDe } from "./aide.js";
import { REPONSE_TURN } from "./turn.js";

const QUATRE_HEURES = 4 * 60 * 60 * 1000;
const TRENTE_SECONDES = 30 * 1000;

/** L'alarme de la salle `code` et le nombre de ses tables SQLite à nous (`pairs`). */
async function etat(code) {
	return runInDurableObject(salleDe(code), async (_salle, ctx) => ({
		alarme: await ctx.storage.getAlarm(),
		tables: ctx.storage.sql.exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pairs'").toArray().length,
	}));
}

/** La fiche de la socket d'étiquette `tag` (`hote` ou l'id d'un client) dans la salle `code`. */
async function fiche(code, tag) {
	return runInDurableObject(salleDe(code), (_salle, ctx) => ctx.getWebSockets(String(tag))[0].deserializeAttachment());
}

/** Forge les champs `champs` (une échéance) dans la fiche de la socket d'étiquette `tag`. */
async function forger(code, tag, champs) {
	await runInDurableObject(salleDe(code), (_salle, ctx) => {
		for (const ws of ctx.getWebSockets(String(tag))) ws.serializeAttachment({ ...ws.deserializeAttachment(), ...champs });
	});
}

/** Pose l'alarme de la salle `code` à `instant`. */
async function poserAlarme(code, instant) {
	await runInDurableObject(salleDe(code), (_salle, ctx) => ctx.storage.setAlarm(instant));
}

describe("expiration à 4 h", () => {
	it("la création pose l'alarme à 4 h, l'échéance de la salle dans la fiche de l'hôte", async () => {
		const avant = Date.now();
		const { code } = await creerSalle();
		const { alarme } = await etat(code);
		expect(alarme).toBeGreaterThanOrEqual(avant + QUATRE_HEURES);
		expect(alarme).toBeLessThanOrEqual(Date.now() + QUATRE_HEURES);
		expect((await fiche(code, "hote")).expire).toBe(alarme);
	});

	it("l'alarme à l'échéance ferme la salle : erreur expiree à tous, stockage effacé, plus d'arrivée", async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		await forger(code, "hote", { expire: Date.now() - 1 });
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect(await hote.suivant()).toEqual({ t: "erreur", raison: "expiree" });
		expect(await hote.fermeture).toEqual({ code: 1000, raison: "expiree" });
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "expiree" });
		expect(await etat(code)).toEqual({ alarme: null, tables: 0 });
		const tard = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await tard.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
	});

	it("une alarme avant toute échéance ne ferme rien et se repose à la prochaine", async () => {
		const { hote, code } = await creerSalle();
		const { client, id } = await arriver(hote, code);
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect((await etat(code)).alarme).toBe((await fiche(code, id)).limite);
		hote.envoyer('{"t":"ping"}');
		expect(await hote.suivant()).toEqual({ t: "pong" });
		client.envoyer('{"t":"ping"}');
		expect(await client.suivant()).toEqual({ t: "pong" });
	});

	it("l'hôte parti efface l'alarme et le stockage", async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		hote.fermer();
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
		await expect.poll(() => etat(code)).toEqual({ alarme: null, tables: 0 });
	});

	it("une alarme orpheline (salle sans hôte) efface le stockage, sans rien d'autre", async () => {
		const code = "ZZZZZ2";
		await runInDurableObject(salleDe(code), async (_salle, ctx) => {
			ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS pairs (id INTEGER PRIMARY KEY)");
			await ctx.storage.setAlarm(Date.now() + 60000);
		});
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect(await etat(code)).toEqual({ alarme: null, tables: 0 });
		const tard = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await tard.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
	});
});

describe("délai d'arrivée de 30 s", () => {
	it("chaque arrivant a son échéance à 30 s ; l'alarme passe à la plus proche, jamais plus tard", async () => {
		expect(LIMITES.DELAI_ARRIVEE_MS).toBe(TRENTE_SECONDES);
		const { hote, code } = await creerSalle();
		const avant = Date.now();
		const a = await arriver(hote, code);
		const { limite } = await fiche(code, a.id);
		expect(limite).toBeGreaterThanOrEqual(avant + TRENTE_SECONDES);
		expect(limite).toBeLessThanOrEqual(Date.now() + TRENTE_SECONDES);
		expect((await etat(code)).alarme).toBe(limite);
		// Une alarme déjà plus proche que l'échéance d'un nouvel arrivant reste où elle est.
		const proche = Date.now() + 5000;
		await poserAlarme(code, proche);
		await arriver(hote, code);
		expect((await etat(code)).alarme).toBe(proche);
	});

	it("un arrivant fantôme est balayé : erreur delai, depart chez l'hôte, sa place resert (même après éviction)", async () => {
		const { hote, code } = await creerSalle();
		const arrivants = [];
		for (let i = 0; i < 6; i++) arrivants.push(await arriver(hote, code));
		const [fantome, ...autres] = arrivants;
		await forger(code, fantome.id, { limite: Date.now() - 1 });
		await evictDurableObject(salleDe(code));
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect(await fantome.client.suivant()).toEqual({ t: "erreur", raison: "delai" });
		expect(await fantome.client.fermeture).toEqual({ code: 1000, raison: "delai" });
		expect(await hote.suivant()).toEqual({ t: "depart", id: fantome.id });
		expect((await arriver(hote, code)).bienvenue.t).toBe("bienvenue");
		for (const { client } of autres) expect(client.enAttente()).toBe(0);
	});

	it("le balayage repose l'alarme à la prochaine échéance, puis à l'expiration de la salle", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		const b = await arriver(hote, code);
		const echeanceB = Date.now() + 10000;
		await forger(code, a.id, { limite: Date.now() - 1 });
		await forger(code, b.id, { limite: echeanceB });
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect(await a.client.suivant()).toEqual({ t: "erreur", raison: "delai" });
		expect((await etat(code)).alarme).toBe(echeanceB);
		await forger(code, b.id, { limite: Date.now() - 1 });
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect(await b.client.suivant()).toEqual({ t: "erreur", raison: "delai" });
		expect((await etat(code)).alarme).toBe((await fiche(code, "hote")).expire);
	});

	it("ouvert ou un départ retire l'échéance : le balayage ignore ce client", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		const b = await arriver(hote, code);
		hote.envoyer({ t: "ouvert", id: a.id });
		await a.client.fermeture;
		b.client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id: b.id });
		await forger(code, a.id, { limite: Date.now() - 1 });
		await forger(code, b.id, { limite: Date.now() - 1 });
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect(hote.enAttente()).toBe(0);
		expect((await etat(code)).alarme).toBe((await fiche(code, "hote")).expire);
	});

	it("l'hôte parti pendant l'appel TURN d'une arrivée : aucune alarme ne survit à la salle", async () => {
		const { hote, code } = await creerSalle();
		// L'appel TURN de l'arrivée dure 300 ms ; l'hôte part pendant ce temps.
		vi.mocked(fetch).mockImplementationOnce(async () => {
			await new Promise((resoudre) => setTimeout(resoudre, 300));
			return Response.json(REPONSE_TURN, { status: 201 });
		});
		const arrivee = ouvrir(`/v1/rejoindre/${code}`);
		await new Promise((resoudre) => setTimeout(resoudre, 100));
		hote.fermer();
		const client = await arrivee;
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
		expect(await etat(code)).toEqual({ alarme: null, tables: 0 });
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
