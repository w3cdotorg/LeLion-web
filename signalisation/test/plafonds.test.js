import { runInDurableObject } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { arriver, creerSalle, ouvrir, salleDe } from "./aide.js";

const REPONSE = { t: "reponse", vers: 1, sdp: "v=0" };

/** Un message `reponse` dont le JSON fait exactement `octets` octets UTF-8, en `motif` répété. */
function reponseDe(octets, motif = "a") {
	const vide = JSON.stringify({ ...REPONSE, sdp: "" });
	const largeur = new TextEncoder().encode(motif).length;
	return JSON.stringify({ ...REPONSE, sdp: motif.repeat(Math.floor((octets - vide.length) / largeur)) });
}

describe("7 sockets par salle", () => {
	it("l'hôte et 6 arrivants ; le 7e arrivant reçoit erreur pleine, une place libérée resert", async () => {
		const { hote, code } = await creerSalle();
		const arrivants = [];
		for (let i = 0; i < 6; i++) arrivants.push(await arriver(hote, code));
		const refuse = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await refuse.suivant()).toEqual({ t: "erreur", raison: "pleine" });
		expect(await refuse.fermeture).toMatchObject({ code: 1000 });
		hote.envoyer({ t: "ouvert", id: arrivants[0].id });
		await arrivants[0].client.fermeture;
		expect((await arriver(hote, code)).bienvenue.t).toBe("bienvenue");
		arrivants[1].client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id: arrivants[1].id });
		expect((await arriver(hote, code)).bienvenue.t).toBe("bienvenue");
	});
});

describe("16 Ko par message", () => {
	it("16 384 octets passent, un de plus : erreur debit, fermeture, depart chez l'hôte", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		const juste = reponseDe(16384);
		expect(new TextEncoder().encode(juste).length).toBe(16384);
		a.client.envoyer(juste);
		expect((await hote.suivant()).t).toBe("reponse");
		a.client.envoyer(reponseDe(16385));
		expect(await a.client.suivant()).toEqual({ t: "erreur", raison: "debit" });
		expect(await a.client.fermeture).toEqual({ code: 1000, raison: "debit" });
		expect(await hote.suivant()).toEqual({ t: "depart", id: a.id });
	});

	it("la taille se compte en octets UTF-8, pas en caractères", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		const lourd = reponseDe(16386, "é");
		expect(lourd.length).toBeLessThan(16384);
		a.client.envoyer(lourd);
		expect(await a.client.suivant()).toEqual({ t: "erreur", raison: "debit" });
	});
});

describe("20 messages par seconde et par socket", () => {
	it("20 d'affilée passent ; une seconde plus tard, 20 de plus", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		for (let tour = 0; tour < 2; tour++) {
			for (let i = 0; i < 20; i++) a.client.envoyer(REPONSE);
			for (let i = 0; i < 20; i++) expect((await hote.suivant()).t).toBe("reponse");
			await new Promise((resoudre) => setTimeout(resoudre, 1050));
		}
		expect(a.client.enAttente()).toBe(0);
	});

	it("au-delà : erreur debit, fermeture, depart chez l'hôte", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		for (let i = 0; i < 30; i++) a.client.envoyer(REPONSE);
		expect(await a.client.suivant()).toEqual({ t: "erreur", raison: "debit" });
		expect(await a.client.fermeture).toEqual({ code: 1000, raison: "debit" });
		let relayes = 0;
		for (let m = await hote.suivant(); m.t !== "depart"; m = await hote.suivant()) relayes++;
		expect(relayes).toBeGreaterThanOrEqual(20);
		expect(relayes).toBeLessThan(30);
	});

	it("un hôte au-delà : erreur debit chez lui, la salle se ferme (erreur inconnue aux arrivants)", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		for (let i = 0; i < 30; i++) hote.envoyer({ t: "offre", vers: a.id, sdp: "v=0" });
		let m = await hote.suivant();
		expect(m).toEqual({ t: "erreur", raison: "debit" });
		for (m = await a.client.suivant(); m.t === "offre"; m = await a.client.suivant());
		expect(m).toEqual({ t: "erreur", raison: "inconnue" });
		const tard = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await tard.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
	});

	it("une horloge qui recule ne vide pas le seau (le temps écoulé compte pour 0)", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		// L'instant du seau dans une minute : vu d'ici, l'horloge a reculé d'une minute.
		await runInDurableObject(salleDe(code), (_salle, ctx) => {
			for (const ws of ctx.getWebSockets(String(a.id))) ws.serializeAttachment({ ...ws.deserializeAttachment(), instant: Date.now() + 60000 });
		});
		for (let i = 0; i < 20; i++) a.client.envoyer(REPONSE);
		for (let i = 0; i < 20; i++) expect(await hote.suivant()).toEqual({ t: "reponse", sdp: "v=0", de: a.id });
		expect(a.client.enAttente()).toBe(0);
	});

	it("le battement ne compte pas : 50 ping de suite reçoivent 50 pong", async () => {
		const { hote } = await creerSalle();
		for (let i = 0; i < 50; i++) hote.envoyer('{"t":"ping"}');
		for (let i = 0; i < 50; i++) expect(await hote.suivant()).toEqual({ t: "pong" });
	});
});

describe("limite de création par IP", () => {
	it("5 salles par minute et par IP, la 6e reçoit erreur debit ; une autre IP crée encore", async () => {
		// Les fenêtres de la limitation locale sont calées sur la minute de l'horloge : ne pas en chevaucher deux.
		const reste = 60000 - (Date.now() % 60000);
		if (reste < 10000) await new Promise((resoudre) => setTimeout(resoudre, reste + 100));
		const ip = "203.0.113.7";
		for (let i = 0; i < 5; i++) expect((await creerSalle({ ip })).salle.t).toBe("salle");
		const sixieme = await ouvrir("/v1/creer", { ip });
		expect(await sixieme.suivant()).toEqual({ t: "erreur", raison: "debit" });
		expect((await creerSalle({ ip: "203.0.113.8" })).salle.t).toBe("salle");
	}, 20000);
});
