// Le point d'entrée du Worker (spec §4.1, §8.1) : les routes /v1, l'origine, les limites de création
// et d'arrivée par IP, puis la salle (Durable Object `Salle`, un par code) qui garde la socket.
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
		const cle = requete.headers.get("cf-connecting-ip") ?? "local";
		return code === null ? creer(requete, env, cle) : rejoindre(requete, env, code, cle);
	},
};

function salle(env, code) {
	return env.SALLES.get(env.SALLES.idFromName(code));
}

/**
 * Vrai si le limiteur `limite` (binding ratelimits) admet encore `cle`. Injoignable, il laisse passer
 * (ouvert par défaut) : c'est un frein, et sa panne ne doit pas fermer le service.
 */
async function admis(limite, cle) {
	try {
		return (await limite.limit({ key: cle })).success;
	} catch (erreur) {
		journal("limite injoignable", { erreur: String(erreur) });
		return true;
	}
}

/** Un code libre (la salle répond 409 si le sien a déjà un hôte), sa salle crée l'hôte. */
async function creer(requete, env, cle) {
	if (!(await admis(env.LIMITE_CREATION, cle))) {
		journal("trop de salles créées par cette IP");
		return refuser("debit");
	}
	try {
		for (let essai = 0; essai < ESSAIS_CODE; essai++) {
			const code = tirerCode();
			const reponse = await salle(env, code).fetch(new Request(`https://salle/creer?code=${code}`, requete));
			if (reponse.status !== 409) return reponse;
			await reponse.body?.cancel(); // un corps jamais lu retiendrait la réponse
		}
	} catch (erreur) {
		journal("salle injoignable", { erreur: String(erreur) });
		return refuser("quota");
	}
	journal("aucun code libre", { essais: ESSAIS_CODE });
	return refuser("quota");
}

/** Un Durable Object qui échoue est, sur l'offre gratuite, un quota épuisé (spec §8.1). */
async function rejoindre(requete, env, code, cle) {
	if (!(await admis(env.LIMITE_ARRIVEE, cle))) {
		journal("trop d'arrivées pour cette IP");
		return refuser("debit");
	}
	try {
		return await salle(env, code).fetch(new Request("https://salle/rejoindre", requete));
	} catch (erreur) {
		journal("salle injoignable", { erreur: String(erreur) });
		return refuser("quota");
	}
}
