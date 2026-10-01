// Une salle (Durable Object, une par code) : l'hôte, les arrivants en cours, le relais entre eux
// (spec §4.2, §4.3, §8.1). Tout son état vit dans les sockets (étiquettes, fiches attachées) et dans
// son stockage SQLite : il survit à l'hibernation, qui ne garde rien en mémoire.
import { DurableObject } from "cloudflare:workers";
import { fabriquerIce } from "./ice.js";
import { ID_HOTE, PING, PONG, envoyer, fermer, refuser } from "./protocole.js";

/** La fiche attachée à une socket (`serializeAttachment`) : rôle, identifiant, fin. */
function nouvelleFiche(role, id) {
	return { role, id, fin: null };
}

const estTexte = (valeur) => typeof valeur === "string";
const estIndex = (valeur) => Number.isInteger(valeur) && valeur >= 0;

/** Les champs de chaque message relayé, en plus de `t` et `vers` : aucun autre n'est admis. */
const RELAYES = {
	offre: { sdp: estTexte },
	reponse: { sdp: estTexte },
	candidat: { media: estTexte, index: estIndex, nom: estTexte },
};

/** Le message décodé s'il est un objet JSON à champ `t` texte, sinon `null`. */
function lire(message) {
	if (typeof message !== "string") return null;
	try {
		const objet = JSON.parse(message);
		return objet !== null && typeof objet === "object" && !Array.isArray(objet) && estTexte(objet.t) ? objet : null;
	} catch {
		return null;
	}
}

/** Vrai si `m` a exactement les champs `t`, `vers` (entier) et ceux de son type, bien typés. */
function relayable(m) {
	const champs = Object.hasOwn(RELAYES, m.t) ? RELAYES[m.t] : null; // ni « constructor » ni « __proto__ »
	if (!champs || !Number.isInteger(m.vers)) return false;
	const noms = Object.keys(m);
	if (noms.length !== Object.keys(champs).length + 2) return false;
	return noms.every((nom) => nom === "t" || nom === "vers" || (Object.hasOwn(champs, nom) && champs[nom](m[nom])));
}

export class Salle extends DurableObject {
	constructor(ctx, env) {
		super(ctx, env);
		ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair(PING, PONG));
	}

	async fetch(requete) {
		const url = new URL(requete.url);
		if (url.pathname === "/creer") return this.accueillirHote(url.searchParams.get("code"));
		if (url.pathname === "/rejoindre") return this.accueillirClient();
		return new Response("introuvable\n", { status: 404 });
	}

	/** Les sockets ouvertes que la salle n'a pas oubliées (toutes, ou celles de l'étiquette `tag`). */
	vivantes(tag) {
		return this.ctx.getWebSockets(tag).filter((ws) => ws.readyState === WebSocket.OPEN && !ws.deserializeAttachment()?.fin);
	}

	hote() {
		return this.vivantes("hote")[0] ?? null;
	}

	/** Le client `id` encore suivi par la salle, ou `null`. */
	client(id) {
		return this.vivantes(String(id)).find((ws) => ws.deserializeAttachment().role === "client") ?? null;
	}

	async accueillirHote(code) {
		if (this.hote()) return new Response("salle occupée\n", { status: 409 });
		const [client, serveur] = Object.values(new WebSocketPair());
		this.ctx.acceptWebSocket(serveur, ["hote"]);
		serveur.serializeAttachment(nouvelleFiche("hote", ID_HOTE));
		this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS pairs (id INTEGER PRIMARY KEY)");
		envoyer(serveur, { t: "salle", code, id: ID_HOTE, ice: await fabriquerIce(this.env) });
		return new Response(null, { status: 101, webSocket: client });
	}

	async accueillirClient() {
		const hote = this.hote();
		if (!hote) return refuser("inconnue");
		const id = this.tirerId();
		const [client, serveur] = Object.values(new WebSocketPair());
		this.ctx.acceptWebSocket(serveur, ["client", String(id)]);
		serveur.serializeAttachment(nouvelleFiche("client", id));
		// Un seul jeu d'identifiants par arrivée, neuf pour l'arrivant comme pour l'hôte (spec §4.2).
		const ice = await fabriquerIce(this.env);
		envoyer(serveur, { t: "bienvenue", id, ice });
		envoyer(hote, { t: "arrivee", id, ice });
		return new Response(null, { status: 101, webSocket: client });
	}

	/** Un identifiant de pair dans 2..2³¹-1, jamais donné dans cette salle (table `pairs`). */
	tirerId() {
		const sql = this.ctx.storage.sql;
		const tirage = new Uint32Array(1);
		for (;;) {
			crypto.getRandomValues(tirage);
			const id = tirage[0] & 0x7fffffff;
			if (id < 2 || sql.exec("SELECT id FROM pairs WHERE id = ?", id).toArray().length > 0) continue;
			sql.exec("INSERT INTO pairs (id) VALUES (?)", id);
			return id;
		}
	}

	async webSocketMessage(ws, message) {
		const fiche = ws.deserializeAttachment();
		if (!fiche || fiche.fin) return;
		const m = lire(message);
		if (m === null) return;
		if (fiche.role === "hote") this.deLHote(m);
		else this.duClient(fiche, m);
	}

	/** `ouvert` (la salle oublie ce client), ou un relais vers un client suivi ; le reste est ignoré. */
	deLHote(m) {
		if (m.t === "ouvert") {
			if (Object.keys(m).length !== 2 || !Number.isInteger(m.id)) return;
			const client = this.client(m.id);
			if (client) this.oublier(client, "ouvert");
			return;
		}
		if (!relayable(m)) return;
		const client = this.client(m.vers);
		const { vers, ...contenu } = m;
		if (client) envoyer(client, { ...contenu, de: ID_HOTE });
	}

	/** Un relais vers l'hôte seulement, jamais vers un autre client ; le reste est ignoré. */
	duClient(fiche, m) {
		if (!relayable(m) || m.vers !== ID_HOTE) return;
		const hote = this.hote();
		const { vers, ...contenu } = m;
		if (hote) envoyer(hote, { ...contenu, de: fiche.id });
	}

	/** La salle ne suit plus le client `ws` (`ouvert`, ou chassé) et le ferme ; `depart` à l'hôte sauf après `ouvert`. */
	oublier(ws, raison) {
		const fiche = ws.deserializeAttachment();
		fiche.fin = raison;
		ws.serializeAttachment(fiche);
		if (raison !== "ouvert") {
			envoyer(ws, { t: "erreur", raison });
			const hote = this.hote();
			if (hote) envoyer(hote, { t: "depart", id: fiche.id });
		}
		fermer(ws, raison);
	}

	async webSocketClose(ws) {
		await this.perdre(ws);
	}

	async webSocketError(ws) {
		await this.perdre(ws);
	}

	/** Une socket fermée de l'autre côté : l'hôte parti ferme la salle, un client suivi part (`depart`). */
	async perdre(ws) {
		const fiche = ws.deserializeAttachment();
		if (!fiche || fiche.fin) return;
		fiche.fin = "parti";
		ws.serializeAttachment(fiche);
		if (fiche.role === "hote") return this.fermerSalle("inconnue");
		const hote = this.hote();
		if (hote) envoyer(hote, { t: "depart", id: fiche.id });
	}

	/** Fin de la salle (hôte parti) : `erreur` puis fermeture pour tous, stockage effacé. */
	async fermerSalle(raison) {
		for (const ws of this.vivantes()) {
			const fiche = ws.deserializeAttachment();
			fiche.fin = raison;
			ws.serializeAttachment(fiche);
			envoyer(ws, { t: "erreur", raison });
			fermer(ws, raison);
		}
		await this.ctx.storage.deleteAll();
	}
}
