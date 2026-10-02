// Le jeu en ligne de bout en bout (spec §10) : de vrais navigateurs, de vraies connexions WebRTC, la
// signalisation en local. Chaque page est menée par le pilote de l'export « Web pilote »
// (Scripts/PiloteWeb.gd) : des commandes poussées dans window.lelionPilote.commandes, son état relu
// dans window.lelionPilote.etat, par les vrais écrans du jeu (titre, En ligne, salon, manche). Le mobile,
// lui, joue au doigt : de vrais touchers de la page, aux places que l'état du pilote donne ; l'hôte exclut un
// joueur d'un vrai clic sur la croix de sa carte (phase 7).
import { devices, expect, test } from "@playwright/test";

const ALPHABET = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;
const HOTE_PARTI = "L'hôte a quitté la partie";
const EXCLU = "L'hôte t'a exclu de la partie.";
const DECONNECTE = "Tu as été déconnecté";

/**
 * Le bruit connu des consoles des pages : des lignes d'erreur qui ne disent rien du jeu (aucune pour
 * l'instant). Toute autre ligne qui contient « SCRIPT ERROR » ou « ERROR: » (une erreur de script, un
 * push_error, une erreur du moteur), une exception JavaScript de la page (« PAGEERROR », phase 7) ou un client
 * que l'hôte limite (« l'excédent est jeté » : un joueur ne doit jamais l'être) fait échouer le test.
 */
const BRUIT_CONNU = [];

/** Les erreurs des consoles `consoles` (une liste de lignes par page) hors du bruit connu, par page. */
function erreurs(consoles) {
	return consoles.map((lignes) =>
		lignes.filter((ligne) => /SCRIPT ERROR|ERROR:|PAGEERROR|l'excédent est jeté/.test(ligne) && !BRUIT_CONNU.some((bruit) => bruit.test(ligne))),
	);
}

/** Note dans `lignes` la console de `page` et ses exceptions JavaScript (une erreur que la console ne dit pas). */
function ecouter(page, lignes) {
	page.on("console", (message) => lignes.push(message.text()));
	page.on("pageerror", (erreur) => lignes.push(`PAGEERROR ${erreur.message}`));
}

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
	ecouter(page, lignes);
	await page.goto(chemin);
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
	return page;
}

const etat = (page) => page.evaluate(() => JSON.parse(window.lelionPilote.etat));

/**
 * Le mobile du test : un Android en paysage (Pixel 7, 863×360 px CSS : son agent utilisateur donne
 * `web_android` au jeu, l'écran est tactile), sans écran haute densité : le jeu se met à l'échelle de la
 * page, pas de ses pixels, et un rendu logiciel 2,6 fois plus fin ralentirait le conteneur.
 */
const MOBILE = { ...devices["Pixel 7 landscape"], deviceScaleFactor: 1 };
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

test("une manche à trois pages par le lien d'invitation, un joueur exclu qui revient, les lions qui se croisent : même empreinte partout, départ de l'hôte vu @manche", async ({ browser }) => {
	// Le plus long des tests : 216 s mesurés sur les 300 s du réglage commun, quand la machine est bridée
	// (Chromium ralenti rend la manche de 14 s en plus de 60 s) ; une marge, sans toucher aux autres tests.
	test.setTimeout(420_000);
	const consoles = [];
	const hote = await ouvrir(browser, "/", consoles);
	await commander(hote, "duree", 14);
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
		await commander(page, "duree", 14);
		await commander(page, "rejoindre", pseudo);
		await attendre(page, (e) => e.scene === "Salon", `${pseudo} arrive au salon (canal WebRTC ouvert, poignée de main faite)`);
		invites.push(page);
	}
	const pages = [hote, ...invites];
	for (const page of pages) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna,Bruno", "la même table du salon partout");
	}
	// Spec §5 : les canaux non fiables gardent un paquet 100 ms au plus (le correctif de TransportWebRTC : sans lui,
	// le navigateur ignore l'option de Godot et ces canaux sont fiables)
	for (const page of pages) expect((await etat(page)).canaux, "les canaux non fiables, 100 ms").toEqual([100, 100]);

	// L'exclusion (spec §8.2), d'un vrai clic de l'hôte sur la croix de la carte de Bruno : Bruno lit « L'hôte t'a
	// exclu de la partie. » sur l'écran En ligne, sa carte se libère partout ; il revient avec le code, en nouvel
	// arrivant (rien ne l'identifie)
	const bruno = invites[1];
	const salon = (await etat(hote)).salon;
	expect(salon.table[0].croix, "pas de croix sur la carte de l'hôte").toEqual([]);
	expect(salon.table[2].croix.length, "la croix de la carte de Bruno, chez l'hôte").toBe(2);
	expect((await etat(invites[0])).salon.table.every((f) => f.croix.length === 0), "aucune croix chez un client").toBe(true);
	await hote.mouse.click(salon.table[2].croix[0], salon.table[2].croix[1]);
	// Sous Xvfb, sans gestionnaire de fenêtres, le clic monte la fenêtre de l'hôte au-dessus des autres : Firefox
	// ne dessine plus celle d'Anna, entièrement couverte, et son jeu s'y fige (mesuré : 2 images en 3 s). Les
	// fenêtres des invités remontent, dans leur ordre. Fait sous chaque navigateur (Chromium compris, sans dommage) :
	// le test ne dépend pas du navigateur qui le joue.
	for (const page of invites) await page.bringToFront();
	const exclu = await attendre(bruno, (e) => e.scene === "EcranEnLigne" && e.pertes.includes(EXCLU), "Bruno, exclu, revient à l'écran En ligne");
	expect(exclu.ecran.message).toBe(EXCLU);
	for (const page of [hote, invites[0]]) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna", "la carte de Bruno se libère partout");
	}
	await commander(bruno, "rejoindre", "Bruno", code);
	await attendre(bruno, (e) => e.scene === "Salon", "Bruno revient avec le code");
	for (const page of pages) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna,Bruno", "de nouveau la même table partout");
	}

	for (const page of pages) await commander(page, "pret");
	await commander(hote, "demarrer");
	// Les passes partent tout de suite : le pilote attend lui-même la manche commencée (GameState.pret),
	// sans le retard des relectures du test, page après page. Toutes d'abord vers la droite, puis retour
	// (l'aller-retour du pilote) : les lions partent espacés d'un tiers de l'écran et ne se croisent pas (une
	// gerbe qui touche un lion l'étourdit : deux lions face à face s'arrêtent l'un l'autre et peignent à
	// peine) ; Bruno, le plus à droite, que le bord arrête à l'aller (sa gerbe y tombe hors de la ville :
	// mesuré, 1 à 7 cellules sans retour), peint au retour.
	for (const page of pages) await commander(page, "peindre", 1);
	// Puis la rencontre (phase 7, la note de la revue de la phase 4) : chaque lion va au milieu de l'écran en
	// vomissant ; ils s'y heurtent et leurs gerbes les étourdissent, ce que l'hôte décide et que chaque page suit
	for (const page of pages) await commander(page, "rencontrer");
	for (const page of pages) await attendre(page, (e) => e.manche?.en_cours === true, "la manche commence partout", 150_000);

	const fins = [];
	for (const page of pages) fins.push(await attendre(page, (e) => e.empreinte !== "", "la manche de 14 s finit partout", 150_000));
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
	// La rencontre : des chocs (et des étourdissements, comptés), le bilan de l'hôte le même sur chaque page
	const bilans = fins.map((fin) => fin.manche.bilan);
	const somme = (valeurs) => valeurs.reduce((a, b) => a + b, 0);
	console.log(`Rencontre : étourdissements ${bilans[0].etourdissements}, chocs ${bilans[0].chocs}`);
	expect(bilans[1]).toEqual(bilans[0]);
	expect(bilans[2]).toEqual(bilans[0]);
	expect(somme(bilans[0].chocs), `les lions se sont heurtés : ${JSON.stringify(bilans[0])}`).toBeGreaterThan(0);

	const depart = Date.now();
	await commander(hote, "quitter");
	for (const page of invites) await attendre(page, (e) => e.pertes.includes(HOTE_PARTI), "les autres voient l'hôte partir", 9_000);
	// Avant les 10 s de silence : c'est l'adieu de l'hôte, ou la fermeture de son pair, qui l'a dit. La borne
	// laisse de la marge à une CI lente ; la valeur mesurée est journalisée.
	const vu = Date.now() - depart;
	console.log(`Départ de l'hôte vu par les deux autres en ${vu} ms`);
	expect(vu).toBeLessThan(9_000);
	expect(erreurs(consoles), "aucune erreur dans les consoles des trois pages").toEqual([[], [], []]);
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
	const lignes = [];
	ecouter(page, lignes);
	await page.goto("/");
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
	await commander(page, "creer", "Hote");
	const salle = await attendre(page, (e) => e.scene === "Salon" && ALPHABET.test(e.code) && e.salon.bouton_copier.length === 2, "l'hôte a sa salle");
	const [x, y] = salle.salon.bouton_copier;
	await page.mouse.click(x, y);
	await attendre(page, (e) => e.salon.copier === "SALON_LIEN_COPIE", "le bouton dit « Lien copié ! »");
	await expect.poll(() => page.evaluate(() => window.presse)).toEqual({ texte: `http://localhost:8060/?salle=${salle.code}`, issue: "acceptee" });
	expect(erreurs([lignes]), "aucune erreur dans la console").toEqual([[]]);
});

test("un mobile rejoint par le lien et joue au doigt ; en portrait, le voile, et le jeu continue @mobile", async ({ browser }) => {
	// 234 à 248 s mesurés sur les 300 s du réglage commun, la machine bridée à 1 CPU (le gel de 12 s compris) : une
	// marge, comme pour @manche
	test.setTimeout(420_000);
	const consoles = [];
	const hote = await ouvrir(browser, "/", consoles);
	await commander(hote, "duree", 12);
	await commander(hote, "creer", "Hote");
	const salle = await attendre(hote, (e) => e.scene === "Salon" && ALPHABET.test(e.code), "l'hôte a sa salle");
	expect(salle.mobile).toBe(false);

	const contexte = await browser.newContext(MOBILE);
	const mobile = await contexte.newPage();
	const lignes = [];
	consoles.push(lignes);
	ecouter(mobile, lignes);
	await mobile.goto(`/?salle=${salle.code}`);
	await mobile.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
	// Un mobile : pas de Créer une partie, Rejoindre à la taille d'un doigt (44 px CSS au moins)
	const accueil = await attendre(mobile, (e) => e.scene === "EcranEnLigne", "le lien ouvre l'écran En ligne du mobile");
	expect(accueil.mobile).toBe(true);
	expect(accueil.ecran.creer).toBe(false);
	const [x0, y0, x1, y1] = accueil.ecran.rejoindre;
	expect(y1 - y0, `Rejoindre fait ${y1 - y0} px CSS de haut`).toBeGreaterThanOrEqual(44);
	await commander(mobile, "duree", 12);
	// Le pseudo au doigt, dans le vrai champ de la page posé sur celui du jeu (SaisieWeb : le clavier d'un téléphone
	// ne s'ouvre que pour lui) ; ce premier toucher demande aussi le plein écran
	const zones = await mobile.evaluate(() => window.lelionSaisie.zones());
	expect(zones.map((z) => z.id).sort(), "les deux champs publiés à la page").toEqual(["Code", "Pseudo"]);
	const pseudo = zones.find((z) => z.id === "Pseudo");
	expect(pseudo.y + pseudo.h <= y0 || pseudo.y >= y1 || pseudo.x + pseudo.l <= x0 || pseudo.x >= x1, "le champ n'est pas sous Rejoindre").toBe(true);
	await mobile.touchscreen.tap(pseudo.x + pseudo.l / 2, pseudo.y + pseudo.h / 2);
	await expect
		.poll(() => mobile.evaluate(() => document.activeElement === window.lelionSaisie.entree), { message: "le toucher active le champ de la page" })
		.toBe(true);
	const entree = await mobile.evaluate(() => {
		const r = window.lelionSaisie.entree.getBoundingClientRect();
		return { y: r.top, l: r.width, police: parseFloat(getComputedStyle(window.lelionSaisie.entree).fontSize) };
	});
	expect(entree.y, "le champ ouvert remonte vers le haut de l'écran, au-dessus du clavier").toBeLessThan(pseudo.y);
	expect(entree.police, "16 px au moins : Safari n'agrandit pas la page").toBeGreaterThanOrEqual(16);
	// La rangée du jeu remonte sous le champ de la page : les deux au même endroit
	await expect
		.poll(async () => {
			const z = (await mobile.evaluate(() => window.lelionSaisie.zones())).find((z) => z.id === "Pseudo");
			return Math.abs(z.y - entree.y) < 2 && Math.abs(z.l - entree.l) < 2 && z.ouvert;
		}, { message: "le champ du jeu, remonté, est sous celui de la page" })
		.toBe(true);
	await mobile.keyboard.type("Pouce");
	// Entrée dans le pseudo : Rejoindre (le code du lien attend), comme au clavier d'un ordinateur
	await mobile.keyboard.press("Enter");
	await attendre(mobile, (e) => e.scene === "Salon", "le mobile arrive au salon (Entrée dans le pseudo)");
	for (const page of [hote, mobile]) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Pouce", "la même table du salon partout, le pseudo tapé au doigt");
	}
	expect(await mobile.evaluate(() => window.lelionSaisie.zones()), "au salon, plus aucun champ pour la page").toEqual([]);
	expect(await mobile.evaluate(() => getComputedStyle(window.lelionSaisie.entree).display)).toBe("none");
	// Le plein écran, demandé par ce premier toucher (Chromium l'accorde : le toucher est le geste qu'il exige)
	await expect.poll(() => mobile.evaluate(() => document.fullscreenElement !== null), { message: "le premier toucher met le mobile en plein écran" }).toBe(true);

	// Au salon, au doigt : la flèche droite change la couleur, PRÊT rend prêt (vu chez l'hôte)
	const salon = (await etat(mobile)).salon;
	expect(salon.tactile.visible).toBe(true);
	const [dx, dy, cote] = salon.tactile.droite;
	expect(cote, `les boutons tactiles font ${cote} px CSS`).toBeGreaterThanOrEqual(44);
	const couleur = salon.table[1].couleur;
	await mobile.touchscreen.tap(dx, dy);
	await attendre(hote, (e) => e.salon?.table[1].couleur !== couleur, "la flèche touchée change la couleur du mobile, chez l'hôte");
	await mobile.touchscreen.tap(salon.tactile.pret[0], salon.tactile.pret[1]);
	await attendre(hote, (e) => e.salon?.table[1].pret === true, "PRÊT touché : le mobile est prêt, chez l'hôte");

	// En portrait : le voile « Tourne ton téléphone », et le jeu qui continue derrière ; en paysage, plus rien.
	// Playwright ne tourne qu'une page hors du plein écran : le joueur en sort d'abord (le jeu le laisse en sortir).
	await mobile.evaluate(() => document.exitFullscreen());
	await expect.poll(() => mobile.evaluate(() => document.fullscreenElement === null)).toBe(true);
	const paysage = mobile.viewportSize();
	await mobile.setViewportSize({ width: paysage.height, height: paysage.width });
	const voile = await attendre(mobile, (e) => e.voile === true, "en portrait, le voile");
	await attendre(mobile, (e) => e.images > voile.images + 30, "le jeu continue derrière le voile");
	await mobile.setViewportSize(paysage);
	await attendre(mobile, (e) => e.voile === false, "en paysage, plus de voile");

	await commander(hote, "pret");
	await commander(hote, "demarrer");
	await attendre(mobile, (e) => e.manche?.en_cours === true, "la manche commence chez le mobile", 150_000);
	const jeu = (await etat(mobile)).manche;
	expect(jeu.tactile.visible).toBe(true);
	// Les doigts : des touchers Chromium (CDP), chacun tenu, comme deux pouces ; chaque envoi donne tous les doigts posés
	const cdp = await contexte.newCDPSession(mobile);
	const doigts = (type, points) => cdp.send("Input.dispatchTouchEvent", { type, touchPoints: points.map(([x, y], id) => ({ x, y, id })) });
	const [sx, sy] = jeu.tactile.stick;
	const [vx, vy] = jeu.tactile.vomir;
	// Les pouces suivent le lion, comme les yeux d'un joueur : l'état du mobile relu, le stick penché en conséquence,
	// VOMIR tenu, jusqu'à ce que le territoire du mobile (les cellules que lui renvoie l'hôte, qui fait foi) compte
	// une cellule à lui, ou jusqu'à la fin de la manche. La gerbe ne peint que d'une bande de hauteurs du lion : de
	// `cible` (233 px au-dessus des toits) à `plancher` (plus bas, elle tombe sous l'écran), 181 px. Une relecture
	// puis un toucher arrivent tard : le lion fait encore 100 px avant que le pouce ne le retienne (mesuré à 1 comme
	// à 7 images par seconde), et la relecture elle-même tombe jusqu'à 100 px après un seuil. Descendre d'un trait
	// jusqu'à la cible, puis lâcher le bas, laissait le lion jusqu'à 200 px plus bas : en CI, arrêté à 850,6 px (le
	// plancher, 832, plus le rayon de la traceuse : 848), il a vomi 7 s sans rien peindre. Le stick ne descend donc
	// vite (aux quatre cinquièmes : 60 % de la vitesse, la zone morte des actions est de 0,5) que jusqu'à 150 px
	// au-dessus de la bande ; puis en biais, à 20 % de la vitesse sur la verticale (le lion avance, sa gerbe devant
	// lui), jusqu'à son premier quart ; il remonte de même sous son dernier quart, et va de bord en bord.
	const haut = jeu.cible;
	const bas = jeu.plancher;
	const quart = (bas - haut) / 4;
	expect(bas - haut, `la bande où peindre, de ${haut} à ${bas} px`).toBeGreaterThan(150);
	let sens = -1; // son lion part à droite de l'écran : d'abord vers la gauche
	const biais = (vertical) => [sens * Math.sqrt(1 - vertical * vertical), vertical];
	let pose = null;
	let vomir = false;
	const trajet = [];
	// Une échéance à l'horloge murale, comme les autres attentes du test ; le trajet est journalisé à chaque issue
	const echeance = Date.now() + 150_000;
	let dernier = null;
	await doigts("touchStart", [[sx, sy]]);
	try {
		for (;;) {
			// Une courte pause à chaque tour : la boucle ne dispute pas le processeur au jeu
			await mobile.waitForTimeout(80);
			if (Date.now() > echeance) {
				throw new Error(`les pouces : ni cellule du mobile ni fin de manche en 150000 ms (dernier état ${JSON.stringify(dernier)} ; pouces : ${trajet.join(" ; ")})`);
			}
			dernier = await etat(mobile);
			const manche = dernier.manche;
			if (manche === undefined) {
				throw new Error(`les pouces : le mobile n'est plus en manche (scène ${dernier.scene}, dernier état ${JSON.stringify(dernier)} ; pouces : ${trajet.join(" ; ")})`);
			}
			if (manche.finie || manche.territoire[2] > 0) {
				trajet.push(`${manche.finie ? "fin" : "peint"} ${manche.temps.toFixed(1)} s ${manche.lion.map(Math.round)}`);
				break;
			}
			if (manche.lion.length !== 2) continue;
			const [x, y] = manche.lion;
			if (x < 300) sens = 1;
			else if (x > 1500) sens = -1;
			// La pente du stick, en rayons : le stick poussé au-delà de son bord donne toute la vitesse, dans sa direction
			let pente;
			if (y < haut - 150) pente = [0, 0.8];
			else if (y < haut + quart) pente = biais(0.2).map((v) => v * 1.2);
			else if (y > bas - quart) pente = biais(-0.2).map((v) => v * 1.2);
			else pente = [sens * 1.2, 0];
			const stick = [sx + pente[0] * jeu.tactile.rayon, sy + pente[1] * jeu.tactile.rayon];
			const nouvelle = stick.join(",");
			if (nouvelle === pose) continue;
			pose = nouvelle;
			trajet.push(`${manche.temps.toFixed(1)} s ${Math.round(x)},${Math.round(y)} ${pente.map((v) => v.toFixed(2)).join("/")}${manche.vomit ? " vomit" : ""}`);
			await doigts("touchMove", vomir ? [stick, [vx, vy]] : [stick]);
			if (!vomir && y >= haut - 150) {
				await doigts("touchStart", [stick, [vx, vy]]);
				vomir = true;
			}
		}
	} finally {
		console.log(`Pouces (bande ${haut} à ${bas} px) : ${trajet.join(" ; ")}`);
		await doigts("touchEnd", []);
	}

	const fins = [];
	for (const page of [hote, mobile]) fins.push(await attendre(page, (e) => e.empreinte !== "", "la manche finit partout", 150_000));
	const empreintes = consoles.map((l) => l.find((ligne) => ligne.startsWith("EMPREINTE ")));
	expect(empreintes[0]).toBeTruthy();
	expect(empreintes[1]).toBe(empreintes[0]);
	console.log(`Fin de manche : scores ${fins[0].scores} ; hôte ${fins[0].fps} i/s, mobile ${fins[1].fps} i/s`);
	// Les scores du territoire : à l'index 0 les cellules de personne, puis l'hôte, puis le mobile
	expect(fins[1].scores[2], `le mobile a peint au doigt : ${fins[1].scores} (pouces : ${trajet.join(" ; ")})`).toBeGreaterThan(0);

	// Un téléphone verrouillé (ou un onglet caché, spec §5) : la page ne rend plus la main, plus aucune image ; 10 s
	// plus tard, l'hôte déclare le mobile parti. À son retour, « Tu as été déconnecté », puis l'écran En ligne
	await mobile.evaluate(() => {
		const fin = Date.now() + 12_000;
		while (Date.now() < fin);
	});
	await attendre(mobile, (e) => e.pertes.includes(DECONNECTE), "au retour, « Tu as été déconnecté »", 15_000);
	const retour = await attendre(mobile, (e) => e.scene === "EcranEnLigne", "puis l'écran En ligne", 15_000);
	expect(retour.ecran.message).toBe(DECONNECTE);
	expect(retour.pertes, "pas « L'hôte a quitté la partie »").not.toContain(HOTE_PARTI);
	expect(erreurs(consoles), "aucune erreur dans les consoles des deux pages").toEqual([[], []]);
});
