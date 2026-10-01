// Le point d'entrée du Worker (spec §4.1, §8.1) : les routes /v1 et l'origine, puis la salle
// (Durable Object `Salle`, un par code) qui garde la socket.
// Le module principal n'exporte que des gestionnaires (`default`, `Salle`) : workerd refuse d'en
// démarrer un qui exporte autre chose (constante, fonction).
import { ESSAIS_CODE, lireCode, tirerCode } from "./code.js";
import { origineAdmise } from "./origine.js";
import { journal, refuser } from "./protocole.js";

export { Salle } from "./salle.js";

const CREER = "/v1/creer";
const REJOINDRE = "/v1/rejoindre/";

export default {
	async fetch(requete, env) {
		const { pathname } = new URL(requete.url);
		let code = null;
		if (pathname.startsWith(REJOINDRE)) {
			code = lireCode(pathname.slice(REJOINDRE.length));
			if (code === null) return new Response("code mal formé\n", { status: 400 });
		} else if (pathname !== CREER) {
			return new Response("introuvable\n", { status: 404 });
		}
		if (requete.method !== "GET") return new Response("GET seulement\n", { status: 405, headers: { Allow: "GET" } });
		if (requete.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
			return new Response("WebSocket attendue\n", { status: 426, headers: { Upgrade: "websocket" } });
		}
		const origine = requete.headers.get("Origin");
		if (!origineAdmise(origine, env.ORIGINES)) {
			journal("origine refusée", { origine });
			return refuser("origine");
		}
		return code === null ? creer(requete, env) : rejoindre(requete, env, code);
	},
};

function salle(env, code) {
	return env.SALLES.get(env.SALLES.idFromName(code));
}

/** Un code libre (la salle répond 409 si le sien a déjà un hôte), sa salle crée l'hôte. */
async function creer(requete, env) {
	try {
		for (let essai = 0; essai < ESSAIS_CODE; essai++) {
			const code = tirerCode();
			const reponse = await salle(env, code).fetch(new Request(`https://salle/creer?code=${code}`, requete));
			if (reponse.status !== 409) return reponse;
		}
	} catch (erreur) {
		journal("salle injoignable", { erreur: String(erreur) });
		return refuser("quota");
	}
	journal("aucun code libre", { essais: ESSAIS_CODE });
	return refuser("quota");
}

/** Un Durable Object qui échoue est, sur l'offre gratuite, un quota épuisé (spec §8.1). */
async function rejoindre(requete, env, code) {
	try {
		return await salle(env, code).fetch(new Request("https://salle/rejoindre", requete));
	} catch (erreur) {
		journal("salle injoignable", { erreur: String(erreur) });
		return refuser("quota");
	}
}
