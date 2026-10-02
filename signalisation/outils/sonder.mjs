// La sonde du Worker déployé (phase 5) : node outils/sonder.mjs <adresse wss://…> [origine refusée]
// 1. /v1/creer depuis l'origine de la page publiée : la salle répond `salle` (un code, l'hôte 1), ses serveurs
//    ICE sont du STUN seul (ni TURN ni identifiants : le déploiement sans TURN) ;
// 2. /v1/creer depuis une origine que la production refuse (http://localhost:8060 par défaut) : `erreur origine`.
// Sort en 0 si tout est vu, en 1 sinon (le message dit quoi). Ouvre une seule salle, aussitôt fermée (l'hôte
// parti, la salle s'efface) : elle compte pour 1 des 5 créations par minute de l'IP qui sonde.
// WebSocket de Node (undici) : l'option `headers` pose l'en-tête Origin, qu'un navigateur poserait lui-même.
const [adresse, refusee = "http://localhost:8060"] = process.argv.slice(2);
const PAGE = "https://w3cdotorg.github.io";
const DELAI_MS = 10_000;

function premierMessage(url, origine) {
	return new Promise((resoudre, rejeter) => {
		const ws = new WebSocket(url, { headers: { Origin: origine } });
		const minuterie = setTimeout(() => {
			ws.close();
			rejeter(new Error(`${url} (Origin ${origine}) : aucun message en ${DELAI_MS} ms`));
		}, DELAI_MS);
		ws.addEventListener("message", (evenement) => {
			clearTimeout(minuterie);
			ws.close(1000, "sonde");
			resoudre(JSON.parse(evenement.data));
		});
		ws.addEventListener("error", () => {
			clearTimeout(minuterie);
			rejeter(new Error(`${url} (Origin ${origine}) : connexion impossible`));
		});
	});
}

function echouer(message) {
	console.error(`::error::${message}`);
	process.exit(1);
}

if (!/^wss:\/\/[a-z0-9.-]+$/.test(adresse ?? "") && !/^ws:\/\/localhost:\d+$/.test(adresse ?? "")) {
	echouer(`adresse du Worker invalide : « ${adresse} » (attendu wss://hôte, sans chemin ni « / » final)`);
}
try {
	const salle = await premierMessage(`${adresse}/v1/creer`, PAGE);
	if (salle.t !== "salle" || !/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/.test(salle.code) || salle.id !== 1) {
		echouer(`depuis ${PAGE}, attendu une salle, reçu ${JSON.stringify(salle)}`);
	}
	const urls = (salle.ice ?? []).flatMap((serveur) => serveur.urls ?? []);
	const turn = (salle.ice ?? []).some((serveur) => serveur.username || serveur.credential) || urls.some((url) => !url.startsWith("stun:"));
	if (urls.length === 0 || turn) echouer(`serveurs ICE inattendus (STUN seul attendu) : ${JSON.stringify(salle.ice)}`);
	console.log(`salle ${salle.code} créée depuis ${PAGE}, ICE : ${urls.join(" ")}`);
	const refus = await premierMessage(`${adresse}/v1/creer`, refusee);
	if (refus.t !== "erreur" || refus.raison !== "origine") echouer(`depuis ${refusee}, attendu erreur origine, reçu ${JSON.stringify(refus)}`);
	console.log(`origine ${refusee} refusée (erreur origine)`);
} catch (erreur) {
	echouer(erreur.message);
}
