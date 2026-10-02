// L'export publié tel que Pages le sert (phase 5, spec §11 ; playwright.publie.config.js) : sans pilote (ni
// window.lelionPilote, ni « PILOTE PRET »), il parle au Worker de project.godot (lelion/signalisation/url), et
// un refus de la signalisation s'y lit au journal. La page s'ouvre sur un lien d'invitation : le titre passe à
// l'écran En ligne, le code rempli, le focus au pseudo ; Entrée (deux fois : l'édition, puis la validation)
// lance Rejoindre, sans viser de pixels.
import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

const PROJET = readFileSync(new URL("../../project.godot", import.meta.url), "utf8");
const URL_WORKER = /^signalisation\/url="([^"]*)"$/m.exec(PROJET)?.[1];
const EN_DIRECT = process.env.SIGNALISATION_EN_DIRECT === "1";
const CODE = "K7Q2XM";

test("l'export publié : le pilote inerte, la signalisation du Worker de project.godot @publie", async ({ page }) => {
	expect(URL_WORKER, "lelion/signalisation/url de project.godot").toMatch(/^wss:\/\/[a-z0-9.-]+$/);
	const lignes = [];
	page.on("console", (message) => lignes.push(message.text()));
	page.on("pageerror", (erreur) => lignes.push(`PAGEERROR ${erreur.message}`));
	const sockets = [];
	if (EN_DIRECT) {
		page.on("websocket", (ws) => sockets.push(ws.url()));
	} else {
		// La salle simulée refuse l'origine, comme le vrai Worker refuse une page servie hors de Pages.
		await page.routeWebSocket(/.*/, (ws) => {
			sockets.push(ws.url());
			ws.send(JSON.stringify({ t: "erreur", raison: "origine" }));
			ws.close({ code: 1000, reason: "origine" });
		});
	}
	await page.goto(`/?salle=${CODE}`);
	await expect.poll(() => lignes.some((ligne) => ligne.startsWith("Godot Engine v")), { timeout: 60_000 }).toBe(true);
	await expect
		.poll(
			async () => {
				if (sockets.length === 0) await page.keyboard.press("Enter");
				return sockets.length;
			},
			{ timeout: 60_000, intervals: [500] },
		)
		.toBeGreaterThan(0);
	expect(sockets).toEqual([`${URL_WORKER}/v1/rejoindre/${CODE}`]);
	await expect
		.poll(() => lignes.some((ligne) => ligne.includes("Signalisation : erreur « origine »")), { timeout: 15_000 })
		.toBe(true);
	expect(await page.evaluate(() => typeof window.lelionPilote)).toBe("undefined");
	expect(lignes.filter((ligne) => /PILOTE PRET|SCRIPT ERROR|PAGEERROR|ws:\/\/localhost/.test(ligne))).toEqual([]);
	console.log(`Export publié : ${sockets[0]}, refus lu au journal (${EN_DIRECT ? "Worker déployé" : "signalisation simulée"})`);
});

test("l'export publié : les canaux non fiables gardent un paquet 100 ms au plus (le correctif des canaux, hors du pilote) @publie", async ({ page }) => {
	test.skip(EN_DIRECT, "la salle simulée seulement : le Worker déployé refuse cette origine avant toute connexion");
	const lignes = [];
	page.on("console", (message) => lignes.push(message.text()));
	page.on("pageerror", (erreur) => lignes.push(`PAGEERROR ${erreur.message}`));
	// Ce qu'on colle dans la console du navigateur pour le contrôle à la main (docs/essai-en-ligne.md), posé avant
	// le jeu : chaque canal créé y est écrit, tel que le navigateur l'a pris (le correctif s'enroule par-dessus).
	await page.addInitScript(() => {
		const creer = RTCPeerConnection.prototype.createDataChannel;
		RTCPeerConnection.prototype.createDataChannel = function (nom, options) {
			const canal = creer.call(this, nom, options);
			console.log(`canal ${nom} ordonné=${canal.ordered} durée=${canal.maxPacketLifeTime} renvois=${canal.maxRetransmits}`);
			return canal;
		};
	});
	// La salle simulée accueille ce poste (son identifiant, aucun serveur ICE) : son pair naît, et ses canaux.
	await page.routeWebSocket(/.*/, (ws) => ws.send(JSON.stringify({ t: "bienvenue", id: 5, ice: [] })));
	await page.goto(`/?salle=${CODE}`);
	await expect.poll(() => lignes.some((ligne) => ligne.startsWith("Godot Engine v")), { timeout: 60_000 }).toBe(true);
	const canaux = () => lignes.filter((ligne) => ligne.startsWith("canal "));
	await expect
		.poll(
			async () => {
				if (canaux().length === 0) await page.keyboard.press("Enter");
				return canaux().length;
			},
			{ timeout: 60_000, intervals: [500] },
		)
		.toBeGreaterThanOrEqual(4);
	const durees = canaux().map((ligne) => /durée=(\S+)/.exec(ligne)[1]);
	expect(durees.filter((duree) => duree === "100"), canaux().join(" | ")).toHaveLength(2);
	expect(lignes.filter((ligne) => /SCRIPT ERROR|PAGEERROR/.test(ligne))).toEqual([]);
	console.log(`Canaux de l'export publié : ${canaux().join(" | ")}`);
});
