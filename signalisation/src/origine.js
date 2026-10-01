// Les origines admises (spec §8.1) : la variable ORIGINES du Worker.

/**
 * Vrai si `origine` (l'en-tête Origin) est dans `liste` (variable ORIGINES : origines séparées par des
 * virgules). Un motif `schéma://hôte:*` admet cet hôte sur tout port, ou sans port. Origine absente :
 * refusée (le jeu livré est l'export Web, dont le navigateur envoie toujours Origin).
 */
export function origineAdmise(origine, liste) {
	if (!origine) return false;
	return (liste ?? "")
		.split(",")
		.map((motif) => motif.trim())
		.filter(Boolean)
		.some((motif) => {
			if (!motif.endsWith(":*")) return origine === motif;
			const base = motif.slice(0, -2);
			return origine === base || (origine.startsWith(`${base}:`) && /^\d{1,5}$/.test(origine.slice(base.length + 1)));
		});
}
