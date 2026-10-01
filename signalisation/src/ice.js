// Les serveurs ICE donnés aux membres d'une salle (spec §2, §8.1) : STUN toujours, TURN Cloudflare
// quand les secrets TURN_KEY_ID et TURN_KEY_API_TOKEN existent (absents en local : STUN seul).
import { journal } from "./protocole.js";

export const STUN = ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"];
export const API_TURN = "https://rtc.live.cloudflare.com/v1/turn/keys";
/** Durée de validité des identifiants TURN, en secondes (2 h). */
export const DUREE_TURN_S = 7200;
/** Au-delà, la salle se passe du TURN pour cette fois. */
export const DELAI_TURN_MS = 3000;

// Le port 53 de rechange est bloqué par les navigateurs (documentation TURN de Cloudflare).
const PORT_53 = /:53(\?|$)/;

/** La liste `iceServers` d'un membre : STUN, puis le TURN s'il a pu être fabriqué. */
export async function fabriquerIce(env) {
	const ice = [{ urls: [...STUN] }];
	if (!env.TURN_KEY_ID || !env.TURN_KEY_API_TOKEN) return ice;
	try {
		const reponse = await fetch(`${API_TURN}/${encodeURIComponent(env.TURN_KEY_ID)}/credentials/generate-ice-servers`, {
			method: "POST",
			headers: { Authorization: `Bearer ${env.TURN_KEY_API_TOKEN}`, "Content-Type": "application/json" },
			body: JSON.stringify({ ttl: DUREE_TURN_S }),
			signal: AbortSignal.timeout(DELAI_TURN_MS),
		});
		if (!reponse.ok) {
			await reponse.body?.cancel();
			journal("TURN refusé", { statut: reponse.status });
			return ice;
		}
		const { iceServers } = await reponse.json();
		const turn = Array.isArray(iceServers) ? iceServers.flatMap(serveurTurn) : [];
		if (turn.length === 0) journal("TURN sans identifiants");
		return [...ice, ...turn];
	} catch (erreur) {
		journal("TURN injoignable", { erreur: String(erreur) });
		return ice;
	}
}

/** Un serveur TURN de la réponse de l'API, réduit à ses champs utiles et sans le port 53 ; [] sinon. */
function serveurTurn(serveur) {
	if (typeof serveur?.username !== "string" || typeof serveur.credential !== "string" || !Array.isArray(serveur.urls)) return [];
	const urls = serveur.urls.filter((url) => typeof url === "string" && !PORT_53.test(url));
	return urls.length ? [{ urls, username: serveur.username, credential: serveur.credential }] : [];
}
