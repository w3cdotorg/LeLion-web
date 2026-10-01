import { describe, expect, it } from "vitest";
import { arriver, creerSalle } from "./aide.js";

const OFFRE = { t: "offre", sdp: "v=0 offre" };
const REPONSE = { t: "reponse", sdp: "v=0 réponse" };
const CANDIDAT = { t: "candidat", media: "0", index: 0, nom: "candidate:1 1 UDP 1 192.0.2.1 9 typ host" };

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
		a.client.envoyer({ ...OFFRE, vers: b.id });
		a.client.envoyer({ ...CANDIDAT, vers: b.id });
		// Le témoin passe après les deux messages refusés (une socket est servie dans l'ordre).
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		hote.envoyer({ ...OFFRE, vers: b.id });
		expect(await b.client.suivant()).toEqual({ ...OFFRE, de: 1 });
	});

	it("vers inconnu, vers l'hôte lui-même : rien n'est relayé", async () => {
		const { hote, a } = await salleADeux();
		hote.envoyer({ ...OFFRE, vers: 1 });
		hote.envoyer({ ...OFFRE, vers: 999 });
		hote.envoyer({ ...OFFRE, vers: String(a.id) });
		hote.envoyer({ ...OFFRE, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...OFFRE, de: 1 });
		expect(hote.enAttente()).toBe(0);
	});
});

describe("validation", () => {
	it("champs attendus seulement, bien typés, types connus : le reste est ignoré sans fermer", async () => {
		const { hote, a } = await salleADeux();
		const refuses = [
			"pas du JSON",
			"[1,2]",
			"null",
			'"offre"',
			{ t: "inconnu", vers: 1 },
			{ t: "constructor", vers: 1 },
			{ t: "__proto__", vers: 1 },
			{ t: "toString", vers: 1 },
			{ t: "offre", vers: 1 },
			{ ...REPONSE, vers: 1, de: 42 },
			{ ...REPONSE, vers: 1, sdp: 12 },
			{ ...CANDIDAT, vers: 1, index: -1 },
			{ ...CANDIDAT, vers: 1, index: 1.5 },
			{ ...CANDIDAT, vers: 1, nom: undefined },
			{ t: "ouvert", id: 1 },
			{ t: "pong" },
		];
		for (const message of refuses) a.client.envoyer(message);
		a.client.ws.send(new Uint8Array([123, 125]));
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		expect(hote.enAttente()).toBe(0);
	});
});

describe("ouvert", () => {
	it("la salle oublie le client et ferme sa socket, sans depart chez l'hôte", async () => {
		const { hote, a, b } = await salleADeux();
		hote.envoyer({ t: "ouvert", id: a.id });
		expect(await a.client.fermeture).toEqual({ code: 1000, raison: "ouvert" });
		expect(a.client.enAttente()).toBe(0);
		hote.envoyer({ ...OFFRE, vers: a.id });
		b.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: b.id });
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
