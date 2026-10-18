/**
 * 🎮 SIMULATEUR AUTONOME ZÉRO-SAISIE - GENZO-POS
 * Interroge l'API Gateway pour capturer l'ID vivant et simuler la réponse opérateur
 */

const readline = require('node:readline');

const SERVER_URL = "http://localhost:5000";
const API_BASE = `${SERVER_URL}/api/v1/payment`;

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

const runSimulateur = async () => {
    try {
        // 🔑 RÉCUPÉRATION AUTOMATIQUE : Capture de la session active de l'IHM
        const response = await fetch(`${API_BASE}/last-order`);
        if (!response.ok) {
            console.log("\n⚠️  [ATTENTION] Aucune session active trouvée. Cliquez d'abord sur le bouton vert de l'IHM payment.html.");
            rl.close();
            return;
        }
        
        const resData = await response.json();
        const activeSession = resData.data;

        console.log("\n=============================================================");
        console.log("🎮 [GENZO-POS] SIMULATEUR AUTONOME MM (ZÉRO-SAISIE)");
        console.log("=============================================================");
        console.log(`📦 ID Capturé en direct  : ${activeSession.order_id}`);
        console.log(`👤 Abonnement ciblé     : ID ${activeSession.id_abonnement}`);
        console.log(`💳 Forfait sélectionné  : ${activeSession.mois_prolongation} Mois (${activeSession.operateur})`);
        console.log("=============================================================");
        console.log(" [Y] : Solde suffisant — Paiement ACCEPTÉ 🎉 (Bouton Bleu + Reset)");
        console.log(" [N] : Solde insuffisant — Paiement REFUSÉ ❌");
        console.log(" [Q] : Quitter le simulateur");
        console.log("=============================================================");

        rl.question("Saisissez votre option (Y/N/Q) : ", async (answer) => {
            const choice = answer.trim().toUpperCase();

            if (choice === 'Q') { rl.close(); return; }

            let payload = {
                order_id: activeSession.order_id,
                id_abonnement: activeSession.id_abonnement,
                operateur: activeSession.operateur,
                mois_prolongation: activeSession.mois_prolongation,
                status: choice === 'Y' ? "ACCEPTED" : "REFUSED",
                transaction_id: choice === 'Y' ? "TXN-WAVE-AUTO-OK" : "TXN-WAVE-AUTO-FAILED"
            };

            console.log(`\n📡 Envoi de l'état [${payload.status}] au Webhook...`);
            const webhookRes = await fetch(`${API_BASE}/webhook`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            const data = await webhookRes.json();
            console.log("📋 Réponse serveur :", data);
            
            console.log("\n✨ Regardez votre navigateur : le bouton est devenu BLEU et le formulaire a été remis à vide !");
            rl.close();
        });

    } catch (err) {
        console.error("💥 Erreur d'infrastructure :", err.message);
        rl.close();
    }
};

// 🔑 ALIGNEMENT SONARLINT : Traitement de la promesse globale pour détruire l'alerte S9383
runSimulateur().catch((err) => {
    console.error("💥 Échec fatal du simulateur autonome :", err.message);
});
