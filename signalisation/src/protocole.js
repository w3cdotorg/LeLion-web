// Le protocole de signalisation v1 (spec §4.2, §8.1) : plafonds, messages fixes, envois et refus.

/** L'identifiant de pair de l'hôte (celui de `create_server` dans Godot). */
export const ID_HOTE = 1;

export const LIMITES = Object.freeze({
	/** L'hôte et 6 arrivants en cours. */
	SOCKETS: 7,
	/** Taille d'un message reçu, en octets UTF-8. */
	OCTETS: 16 * 1024,
	/** Messages reçus par seconde et par socket (seau de jetons, 20 d'avance au plus). */
	MESSAGES_PAR_SECONDE: 20,
	/** Durée de vie d'une salle. */
	DUREE_SALLE_MS: 4 * 60 * 60 * 1000,
});

/** Le battement de l'hôte et sa réponse, servis par le runtime sans réveiller la salle (texte exact). */
export const PING = '{"t":"ping"}';
export const PONG = '{"t":"pong"}';

/** Envoie `message` en JSON ; faux si la socket est déjà fermée. */
export function envoyer(ws, message) {
	try {
		ws.send(JSON.stringify(message));
		return true;
	} catch {
		return false;
	}
}

/** Ferme `ws` (code 1000, `raison` en motif) ; sans effet sur une socket déjà fermée. */
export function fermer(ws, raison) {
	try {
		ws.close(1000, raison);
	} catch {
		// déjà fermée
	}
}

/** Une socket acceptée le temps de dire `{t:"erreur", raison}`, puis fermée : la réponse 101 qui la porte. */
export function refuser(raison) {
	const [client, serveur] = Object.values(new WebSocketPair());
	serveur.accept();
	envoyer(serveur, { t: "erreur", raison });
	fermer(serveur, raison);
	return new Response(null, { status: 101, webSocket: client });
}

/** Une ligne de journal structurée (Workers Logs) ; jamais de SDP, de candidat ni d'IP. */
export function journal(message, details = {}) {
	console.log(JSON.stringify({ message, ...details }));
}
