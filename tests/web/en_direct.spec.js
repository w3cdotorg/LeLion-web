// Une partie de contrôle sur la page déployée (phase 5, playwright.en_direct.config.js) : la page telle que les
// joueurs l'ouvrent (sans pilote), menée au clavier comme un joueur : l'hôte, sur le titre, Droite (Multijoueur)
// puis Entrée, puis Entrée (Créer une partie, au focus) ; son code se lit dans les messages de la signalisation
// (`salle`) ; l'invité ouvre le lien d'invitation et fait Entrée (Rejoindre). Réussite : l'hôte dit `ouvert` à
// la salle (le canal WebRTC des deux pages est ouvert), les serveurs ICE sont du STUN seul.
import { expect, test } from "@playwright/test";

/** Une page neuve (son propre contexte) qui note sa console et les messages de ses WebSockets. */
async function ouvrir(navigateur, chemin) {
	const page = await (await navigateur.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
	const journal = { lignes: [], recus: [], envoyes: [], sockets: [] };
	page.on("console", (message) => journal.lignes.push(message.text()));
	page.on("pageerror", (erreur) => journal.lignes.push(`PAGEERROR ${erreur.message}`));
	page.on("websocket", (ws) => {
		journal.sockets.push(ws.url());
		ws.on("framereceived", (trame) => journal.recus.push(JSON.parse(trame.payload)));
		ws.on("framesent", (trame) => journal.envoyes.push(JSON.parse(trame.payload)));
	});
	await page.goto(chemin);
	await expect.poll(() => journal.lignes.some((ligne) => ligne.startsWith("Godot Engine v")), { timeout: 90_000 }).toBe(true);
	return { page, journal };
}

/** Appuie sur `touches` (une fois chacune, dans l'ordre) jusqu'à ce que `condition` soit vraie. */
async function jusqua(page, touches, condition, message, delai = 60_000) {
	await expect
		.poll(
			async () => {
				if (!condition()) for (const touche of touches) await page.keyboard.press(touche);
				return condition();
			},
			{ message, timeout: delai, intervals: [1500] },
		)
		.toBe(true);
}

test("deux pages jouent ensemble sur la page déployée : une salle, une arrivée, le canal WebRTC ouvert, STUN seul", async ({ browser }) => {
	const hote = await ouvrir(browser, "./");
	const salle = () => hote.journal.recus.find((message) => message.t === "salle");
	// Le titre a le focus sur Jouer : Droite va à Multijoueur ; l'écran En ligne a le focus sur Créer une partie.
	await jusqua(hote.page, ["ArrowRight", "Enter", "Enter"], () => salle() !== undefined, "l'hôte crée une partie");
	const { code, ice } = salle();
	expect(code).toMatch(/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/);
	const invite = await ouvrir(browser, `./?salle=${code}`);
	const ouvert = () => hote.journal.envoyes.some((message) => message.t === "ouvert");
	await jusqua(invite.page, ["Enter"], () => invite.journal.sockets.length > 0, "l'invité rejoint par le lien");
	await expect.poll(ouvert, { message: "le canal WebRTC entre les deux pages s'ouvre (l'hôte dit ouvert)", timeout: 30_000 }).toBe(true);
	const bienvenue = invite.journal.recus.find((message) => message.t === "bienvenue");
	for (const serveurs of [ice, bienvenue?.ice]) {
		const urls = (serveurs ?? []).flatMap((serveur) => serveur.urls);
		expect(urls.length > 0 && urls.every((url) => url.startsWith("stun:")), JSON.stringify(serveurs)).toBe(true);
	}
	expect(await hote.page.evaluate(() => typeof window.lelionPilote), "le pilote du bout en bout absent de la page").toBe("undefined");
	const erreurs = [hote, invite].flatMap(({ journal }) => journal.lignes.filter((ligne) => /SCRIPT ERROR|ERROR:|PAGEERROR|PILOTE PRET/.test(ligne)));
	expect(erreurs).toEqual([]);
	console.log(`Salle ${code} : ${hote.journal.sockets[0]} ; ${invite.journal.sockets[0]} ; canal ouvert ; ICE ${JSON.stringify(ice)}`);
});
