// Le point d'entrée du Worker de signalisation (spec §4.1) : ses routes viennent avec la Task 3.
export default {
	async fetch() {
		return new Response("introuvable\n", { status: 404 });
	},
};
