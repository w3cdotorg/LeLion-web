// Outils des tests : sockets vers le Worker, file des messages reçus, salles prêtes.
import { env, exports } from "cloudflare:workers";

export const ORIGINE = "https://w3cdotorg.github.io";

/** Une IP de test tirée au hasard (10.x.y.z), pour que la limite par IP ne lie pas les tests entre eux. */
export function ipAuHasard() {
	const [a, b, c] = crypto.getRandomValues(new Uint8Array(3));
	return `10.${a}.${b}.${c}`;
}

/**
 * Attend la minute suivante s'il en reste moins de 10 s : les fenêtres de la limitation de débit locale
 * sont calées sur la minute de l'horloge, un test de limite ne doit pas en chevaucher deux.
 */
export async function loinDuBordDeMinute() {
	const reste = 60000 - (Date.now() % 60000);
	if (reste < 10000) await new Promise((resoudre) => setTimeout(resoudre, reste + 100));
}

/** Une requête vers le Worker (WebSocket demandée, origine admise et IP au hasard par défaut). */
export function requete(chemin, { origine = ORIGINE, ip = ipAuHasard(), upgrade = "websocket", methode = "GET" } = {}) {
	const entetes = new Headers({ "cf-connecting-ip": ip });
	if (upgrade) entetes.set("Upgrade", upgrade);
	if (origine) entetes.set("Origin", origine);
	return new Request(`https://signalisation.test${chemin}`, { method: methode, headers: entetes });
}

/** Ouvre une socket : `{ reponse }` seul si le Worker n'a pas répondu 101, sinon la socket branchée. */
export async function ouvrir(chemin, options) {
	const reponse = await exports.default.fetch(requete(chemin, options));
	if (reponse.status !== 101) return { reponse };
	return { reponse, ...brancher(reponse.webSocket) };
}

/** Accepte la socket `ws` côté test et range ses messages (JSON) dans une file. */
export function brancher(ws) {
	const recus = [];
	let reveil = null;
	const fermeture = new Promise((resoudre) => {
		ws.addEventListener("close", (evenement) => resoudre({ code: evenement.code, raison: evenement.reason }));
	});
	ws.addEventListener("message", (evenement) => {
		recus.push(JSON.parse(evenement.data));
		reveil?.();
	});
	ws.accept();
	return {
		ws,
		fermeture,
		envoyer(message) {
			ws.send(typeof message === "string" ? message : JSON.stringify(message));
		},
		fermer() {
			ws.close(1000, "fin du test");
		},
		/** Le prochain message reçu ; rejette au bout de `delai` ms sans message. */
		async suivant(delai = 2000) {
			if (recus.length === 0) {
				await new Promise((resoudre, rejeter) => {
					const minuterie = setTimeout(() => rejeter(new Error(`aucun message en ${delai} ms`)), delai);
					reveil = () => {
						clearTimeout(minuterie);
						reveil = null;
						resoudre();
					};
				});
			}
			return recus.shift();
		},
		/** Les messages déjà reçus et pas encore lus. */
		enAttente() {
			return recus.length;
		},
	};
}

/** Une salle créée : la socket de l'hôte, le message `salle`, le code. */
export async function creerSalle(options) {
	const hote = await ouvrir("/v1/creer", options);
	const salle = await hote.suivant();
	return { hote, salle, code: salle.code };
}

/** Un arrivant dans la salle `code` : sa socket, son `bienvenue`, l'`arrivee` lue chez l'hôte. */
export async function arriver(hote, code, options) {
	const client = await ouvrir(`/v1/rejoindre/${code}`, options);
	const bienvenue = await client.suivant();
	const arrivee = await hote.suivant();
	return { client, bienvenue, arrivee, id: bienvenue.id };
}

/** Le Durable Object de la salle `code`. */
export function salleDe(code) {
	return env.SALLES.get(env.SALLES.idFromName(code));
}
