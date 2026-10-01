// L'API TURN de Cloudflare simulée : sa réponse (celle de sa documentation, port 53 compris) et
// les `iceServers` qu'un membre doit en recevoir.

export const REPONSE_TURN = {
	iceServers: [
		{ urls: ["stun:stun.cloudflare.com:3478", "stun:stun.cloudflare.com:53"] },
		{
			urls: [
				"turn:turn.cloudflare.com:3478?transport=udp",
				"turn:turn.cloudflare.com:53?transport=udp",
				"turn:turn.cloudflare.com:3478?transport=tcp",
				"turns:turn.cloudflare.com:5349?transport=tcp",
				"turns:turn.cloudflare.com:443?transport=tcp",
			],
			username: "nom-turn",
			credential: "secret-turn",
		},
	],
};

export const ICE_ATTENDU = [
	{ urls: ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"] },
	{
		urls: [
			"turn:turn.cloudflare.com:3478?transport=udp",
			"turn:turn.cloudflare.com:3478?transport=tcp",
			"turns:turn.cloudflare.com:5349?transport=tcp",
			"turns:turn.cloudflare.com:443?transport=tcp",
		],
		username: "nom-turn",
		credential: "secret-turn",
	},
];
