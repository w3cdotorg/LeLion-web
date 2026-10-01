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
