// Le jeu en ligne de bout en bout (spec §10) : de vrais navigateurs, de vraies connexions WebRTC, la
// signalisation en local. Chaque page est menée par le pilote de l'export « Web pilote »
// (Scripts/PiloteWeb.gd) : des commandes poussées dans window.lelionPilote.commandes, son état relu
// dans window.lelionPilote.etat, par les vrais écrans du jeu (titre, En ligne, salon, manche).
import { expect, test } from "@playwright/test";

const ALPHABET = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;
const HOTE_PARTI = "L'hôte a quitté la partie";

/**
 * Une page neuve, la `rang`-ième (son propre contexte : rien de partagé entre joueurs), le pilote prêt.
 * Chaque fenêtre est plus petite que la précédente : sous Xvfb (sans gestionnaire de fenêtres, toutes en
 * haut à gauche), Firefox ne dessine plus une fenêtre entièrement couverte, et son jeu s'y fige.
 */
async function ouvrir(navigateur, chemin, consoles, rang = 0) {
	const largeur = 1280 - 160 * rang;
	const contexte = await navigateur.newContext({ viewport: { width: largeur, height: Math.round((largeur * 9) / 16) } });
	const page = await contexte.newPage();
	const lignes = [];
	consoles?.push(lignes);
	page.on("console", (message) => lignes.push(message.text()));
	await page.goto(chemin);
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
	return page;
}

const etat = (page) => page.evaluate(() => JSON.parse(window.lelionPilote.etat));
const commander = (page, ...commande) => page.evaluate((c) => window.lelionPilote.commandes.push(c), commande);

/** Relit l'état de `page` jusqu'à ce que `condition` le vérifie ; le rend. */
async function attendre(page, condition, message, delai = 30_000) {
	let dernier = null;
	try {
		await expect
			.poll(async () => condition((dernier = await etat(page))), { timeout: delai, intervals: [100, 250] })
			.toBe(true);
	} catch {
		throw new Error(`${message} : pas en ${delai} ms (dernier état ${JSON.stringify(dernier)})`);
	}
	return dernier;
}

test("une manche à trois pages par le lien d'invitation : même empreinte partout, départ de l'hôte vu @manche", async ({ browser }) => {
	const consoles = [];
	const hote = await ouvrir(browser, "/", consoles);
	await commander(hote, "duree", 10);
	await commander(hote, "creer", "Hote");
	const salle = await attendre(hote, (e) => e.scene === "Salon" && ALPHABET.test(e.code), "l'hôte a sa salle");
	const code = salle.code;
	expect(salle.salon.invitation).toBe(`Code de la partie : ${code.slice(0, 3)}-${code.slice(3)}`);

	const invites = [];
	for (const [rang, pseudo] of [[1, "Anna"], [2, "Bruno"]]) {
		const page = await ouvrir(browser, `/?salle=${code}`, consoles, rang);
		// Le lien ouvre l'écran En ligne, le code rempli, sans rien tenter avant le Rejoindre du joueur.
		const accueil = await attendre(page, (e) => e.scene === "EcranEnLigne", `${pseudo} : le lien ouvre l'écran En ligne`);
		expect(accueil.ecran.code).toBe(`${code.slice(0, 3)}-${code.slice(3)}`);
		expect(accueil.en_ligne).toBe(false);
		await commander(page, "duree", 10);
		await commander(page, "rejoindre", pseudo);
		await attendre(page, (e) => e.scene === "Salon", `${pseudo} arrive au salon (canal WebRTC ouvert, poignée de main faite)`);
		invites.push(page);
	}
	const pages = [hote, ...invites];
	for (const page of pages) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna,Bruno", "la même table du salon partout");
	}

	for (const page of pages) await commander(page, "pret");
	await commander(hote, "demarrer");
	// Les passes partent tout de suite : le pilote attend lui-même la manche commencée (GameState.pret),
	// sans le retard des relectures du test, page après page. Toutes vers la gauche : les lions partent
	// espacés d'un tiers de l'écran et ne se croisent pas (deux lions qui se heurtent de face s'arrêtent l'un
	// l'autre et peignent à peine) ; celui de l'hôte, le plus à gauche, peint jusqu'au bord.
	for (const page of pages) await commander(page, "peindre", -1);
	for (const page of pages) await attendre(page, (e) => e.manche?.en_cours === true, "la manche commence partout", 60_000);

	const fins = [];
	for (const page of pages) fins.push(await attendre(page, (e) => e.empreinte !== "", "la manche de 10 s finit partout", 60_000));
	const empreintes = consoles.map((lignes) => lignes.find((l) => l.startsWith("EMPREINTE ")));
	expect(empreintes[0]).toBeTruthy();
	expect(empreintes[1]).toBe(empreintes[0]);
	expect(empreintes[2]).toBe(empreintes[0]);
	// La cadence de chaque page (images par seconde) et sa passe (ticks physiques de la descente, de la
	// peinture) : une page lente en CI se lit ici.
	const cadences = fins.map((fin) => `${fin.fps} i/s, passe ${JSON.stringify(fin.passe)}`).join(" ; ");
	console.log(`Fin de manche : scores ${fins[0].scores} ; ${cadences}`);
	// Les scores du territoire : à l'index 0 les cellules de personne, puis un par joueur (l'hôte, Anna, Bruno).
	for (const fin of fins) expect(fin.scores.slice(1, 4).every((cellules) => cellules > 0), `chacun a peint : ${fin.scores} (${cadences})`).toBe(true);

	const depart = Date.now();
	await commander(hote, "quitter");
	for (const page of invites) await attendre(page, (e) => e.pertes.includes(HOTE_PARTI), "les autres voient l'hôte partir", 9_000);
	// Avant les 10 s de silence : c'est l'adieu de l'hôte, ou la fermeture de son pair, qui l'a dit.
	expect(Date.now() - depart).toBeLessThan(9_000);
});

test("Copier le lien, sous un vrai clic, met le lien d'invitation dans le presse-papiers @lien", async ({ browser }) => {
	const contexte = await browser.newContext();
	// Le presse-papiers lui-même n'est pas lisible ici (WebKit n'accorde pas sa lecture) : on relève ce que le
	// jeu lui donne, et si le navigateur l'accepte (un writeText refusé faute de geste de l'utilisateur échoue).
	await contexte.addInitScript(() => {
		const ecrire = navigator.clipboard.writeText.bind(navigator.clipboard);
		window.presse = { texte: null, issue: "aucune" };
		navigator.clipboard.writeText = (texte) => {
			window.presse.texte = texte;
			return ecrire(texte).then(
				() => { window.presse.issue = "acceptee"; },
				(erreur) => { window.presse.issue = `refusee : ${erreur}`; throw erreur; },
			);
		};
	});
	const page = await contexte.newPage();
	await page.goto("/");
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
	await commander(page, "creer", "Hote");
	const salle = await attendre(page, (e) => e.scene === "Salon" && ALPHABET.test(e.code) && e.salon.bouton_copier.length === 2, "l'hôte a sa salle");
	const [x, y] = salle.salon.bouton_copier;
	await page.mouse.click(x, y);
	await attendre(page, (e) => e.salon.copier === "SALON_LIEN_COPIE", "le bouton dit « Lien copié ! »");
	await expect.poll(() => page.evaluate(() => window.presse)).toEqual({ texte: `http://localhost:8060/?salle=${salle.code}`, issue: "acceptee" });
});
