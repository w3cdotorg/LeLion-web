import { describe, expect, it } from "vitest";
import { arriver, creerSalle } from "./aide.js";

const OFFRE = { t: "offre", sdp: "v=0 offre" };
const REPONSE = { t: "reponse", sdp: "v=0 réponse" };
const CANDIDAT = { t: "candidat", media: "0", index: 0, nom: "candidate:1 1 UDP 1 192.0.2.1 9 typ host" };

/**
 * Le message `modele` marqué comme la sonde `n` (`sdp` ou `nom` à elle) : une sonde relayée par erreur
 * ne se confond jamais avec le témoin qui la suit.
 */
function sonde(modele, n) {
	return modele.t === "candidat" ? { ...modele, nom: `sonde ${n}` } : { ...modele, sdp: `sonde ${n}` };
}

/** Une salle, son hôte et deux arrivants. */
async function salleADeux() {
	const { hote, code } = await creerSalle();
	const a = await arriver(hote, code);
	const b = await arriver(hote, code);
	return { hote, code, a, b };
}

describe("relais hôte ↔ client", () => {
	it("offre et candidat de l'hôte vers un client : vers devient de", async () => {
		const { hote, a } = await salleADeux();
		hote.envoyer({ ...OFFRE, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...OFFRE, de: 1 });
		hote.envoyer({ ...CANDIDAT, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...CANDIDAT, de: 1 });
	});

	it("réponse et candidat d'un client vers l'hôte : de est l'id du client", async () => {
		const { hote, a } = await salleADeux();
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		a.client.envoyer({ ...CANDIDAT, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...CANDIDAT, de: a.id });
	});

	it("jamais d'un client à un autre", async () => {
		const { hote, a, b } = await salleADeux();
		a.client.envoyer({ ...sonde(OFFRE, 1), vers: b.id });
		a.client.envoyer({ ...sonde(CANDIDAT, 2), vers: b.id });
		a.client.envoyer({ ...sonde(REPONSE, 3), vers: b.id });
		// Le témoin passe après les messages refusés (une socket est servie dans l'ordre).
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		hote.envoyer({ ...OFFRE, vers: b.id });
		expect(await b.client.suivant()).toEqual({ ...OFFRE, de: 1 });
		expect(b.client.enAttente()).toBe(0);
	});

	it("vers inconnu, vers l'hôte lui-même, vers en texte : rien n'est relayé", async () => {
		const { hote, a } = await salleADeux();
		hote.envoyer({ ...sonde(OFFRE, 1), vers: 1 });
		hote.envoyer({ ...sonde(OFFRE, 2), vers: 999 });
		hote.envoyer({ ...sonde(OFFRE, 3), vers: String(a.id) });
		a.client.envoyer({ ...sonde(REPONSE, 4), vers: "1" });
		a.client.envoyer({ ...sonde(REPONSE, 5), vers: a.id });
		hote.envoyer({ ...OFFRE, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...OFFRE, de: 1 });
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		expect(a.client.enAttente()).toBe(0);
		expect(hote.enAttente()).toBe(0);
	});
});

describe("validation", () => {
	/**
	 * Le client `a` envoie `refuses` puis un témoin : seul le témoin arrive chez l'hôte, et la socket reste
	 * ouverte. Moins de 20 messages en tout, sous le plafond de débit.
	 */
	async function seulLeTemoinPasse(hote, a, refuses) {
		expect(refuses.length).toBeLessThan(20);
		for (const message of refuses) {
			if (message instanceof Uint8Array) a.client.ws.send(message);
			else a.client.envoyer(message);
		}
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		expect(hote.enAttente()).toBe(0);
	}

	it("JSON invalide, type inconnu ou hérité d'Object, trame binaire : ignorés sans fermer", async () => {
		const { hote, a } = await salleADeux();
		await seulLeTemoinPasse(hote, a, [
			"pas du JSON",
			"[1,2]",
			"null",
			'"offre"',
			{ t: "inconnu", vers: 1 },
			{ t: "constructor", vers: 1 },
			{ t: "__proto__", vers: 1 },
			{ t: "toString", vers: 1 },
			{ t: "ouvert", id: 1 },
			{ t: "pong" },
			new Uint8Array([123, 125]),
		]);
	});

	it("champs attendus seulement, bien typés : un champ en trop, en moins ou mal typé est ignoré sans fermer", async () => {
		const { hote, a } = await salleADeux();
		await seulLeTemoinPasse(hote, a, [
			{ t: "offre", vers: 1 },
			{ ...sonde(REPONSE, 1), vers: 1, de: 42 },
			{ ...sonde(REPONSE, 2), vers: 1, en_plus: 1 },
			{ ...sonde(CANDIDAT, 3), vers: 1, en_plus: 1 },
			{ ...REPONSE, vers: 1, sdp: 12 },
			{ ...sonde(CANDIDAT, 4), vers: 1, index: -1 },
			{ ...sonde(CANDIDAT, 5), vers: 1, index: 1.5 },
			{ ...sonde(CANDIDAT, 6), vers: 1, index: "0" },
			{ ...CANDIDAT, vers: 1, nom: undefined },
			{ ...sonde(CANDIDAT, 7), vers: 1, media: 0 },
		]);
	});
});

describe("ouvert", () => {
	it("la salle oublie le client et ferme sa socket, sans depart chez l'hôte", async () => {
		const { hote, a, b } = await salleADeux();
		hote.envoyer({ t: "ouvert", id: a.id });
		expect(await a.client.fermeture).toEqual({ code: 1000, raison: "ouvert" });
		expect(a.client.enAttente()).toBe(0);
		hote.envoyer({ ...sonde(OFFRE, 1), vers: a.id });
		b.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: b.id });
		expect(hote.enAttente()).toBe(0);
	});

	it("ouvert mal formé ou d'un client : ignoré", async () => {
		const { hote, a } = await salleADeux();
		hote.envoyer({ t: "ouvert", id: String(a.id) });
		hote.envoyer({ t: "ouvert", id: a.id, en_plus: true });
		a.client.envoyer({ t: "ouvert", id: a.id });
		hote.envoyer({ ...OFFRE, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...OFFRE, de: 1 });
	});
});
