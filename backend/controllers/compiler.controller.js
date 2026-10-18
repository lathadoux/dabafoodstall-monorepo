// path: backend/controllers/compiler.controller.js
const { execFile } = require('node:child_process');
const fs = require('node:fs').promises;
const path = require('node:path');
const pool = require('../config/database');

function calculateFactoryPins(whatsappNumber) {
    const cleanNumber = whatsappNumber.replace(/\D/g, '');
    const fallbackPin = 1234;
    
    if (cleanNumber.length < 4) {
        return { adminPin: "1234", managerPin: "1235", vendorPin: "1236" };
    }
    
    const lastFourDigits = Number.parseInt(cleanNumber.slice(-4), 10);
    const basePin = Number.isNaN(lastFourDigits) ? fallbackPin : lastFourDigits;

    const adminPin = String(basePin).padStart(4, '0');
    const managerPin = String((basePin + 1) % 10000).padStart(4, '0');
    const vendorPin = String((basePin + 2) % 10000).padStart(4, '0');

    return { adminPin, managerPin, vendorPin };
}

/**
 * 🚀 DÉCLENCHEUR DE COMPILATION SUR MESURE POST-PAIEMENT (AVEC VERROUS DE PLANS SAAS)
 */
exports.triggerApkCompilationAfterPayment = async (req, res) => {
    const { web_fingerprint } = req.body;

    if (!web_fingerprint) {
        return res.status(400).json({ success: false, message: "Empreinte d'enrôlement absente." });
    }

    try {
        // 1. JOINTURE CRITIQUE POUR RÉCUPÉRER LES OPTIONS DU PLAN DE L'ABONNÉ
        const queryResult = await pool.query(
            `SELECT a.client_nom, a.client_prenom, a.whatsapp_number, a.type_pos, a.date_expiration_cloud,
                    p.option_sauvegarde, p.option_backoffice, p.option_synchro_x_realtime
             FROM abonnements a
             JOIN plans_abonnement p ON a.plan_id = p.plan_id
             WHERE a.web_fingerprint = $1 LIMIT 1`,
            [web_fingerprint]
        );

        if (queryResult.rows.length === 0) {
            return res.status(404).json({ success: false, message: "Aucun abonnement trouvé pour cette empreinte." });
        }

        const data = queryResult.rows[0];
        const nomComplet = `${data.client_nom} ${data.client_prenom}`.trim().toUpperCase();
        
        // 2. CALCUL DU BLOC RH
        const { adminPin, managerPin, vendorPin } = calculateFactoryPins(data.whatsapp_number || "00000000");

        // 3. GESTION DU TEMPLATE METIER
        const templateName = data.type_pos === 'garba_stall' ? 'garba_stall.json' : 'general.json';
        const templatePath = path.join(__dirname, `../templates/${templateName}`);
        
        let catalogueMetier = { familles: [], articles: [] };
        try {
            const templateData = await fs.readFile(templatePath, 'utf8');
            catalogueMetier = JSON.parse(templateData);
    } catch (fileError) {
            // ✅ Conforme SonarLint S2486 : L'exception est interceptée et documentée.
            // Si le fichier de template est introuvable, l'architecture SaaS bascule
            // sur un catalogue vide. L'application mobile se synchronisera ensuite via le réseau.
            console.warn(`⚠️ [SaaS Compiler] Fichier template introuvable (${templateName}) : ${fileError.message}`);
        }
        // 4. CONSTRUCTION DE L'IDENTITY MANIFEST
        const identityManifest = {
            enrolment_fingerprint: web_fingerprint,
            pos_type: data.type_pos,
            compiled_at: new Date().toISOString(),
            license_meta: {
                expires_at: data.date_expiration_cloud,
                allow_backup: data.option_sauvegarde ? 1 : 0,
                allow_backoffice: data.option_backoffice ? 1 : 0,
                allow_realtime_sync: data.option_synchro_x_realtime ? 1 : 0
            },
            factory_rh: [
                { id_user: 1, nom_user: nomComplet, role_user: "admin", initial_pin: adminPin, must_change_pin: 1 },
                { id_user: 2, nom_user: `Gestionnaire ${data.client_nom}`, role_user: "manager", initial_pin: managerPin, must_change_pin: 1 },
                { id_user: 3, nom_user: "Vendeur 1", role_user: "vendor", initial_pin: vendorPin, must_change_pin: 1 }
            ],
            catalogue_template: catalogueMetier
        };

        // 5. EXÉCUTION DU WORKER BASH
        const scriptPath = path.join(__dirname, '../scripts/compile_apk.sh');
        const outputDir = path.join(__dirname, '../public/downloads/apks');
        const manifestString = JSON.stringify(identityManifest);

        console.log(`📦 [BACKEND] Lancement du compilateur avec Plan SaaS pour ${nomComplet}`);

        execFile(scriptPath, [web_fingerprint, manifestString, outputDir], async (error, stdout, stderr) => {
            if (error) {
                console.error(`🛑 [COMPILER CRASH] Échec pour ${web_fingerprint}:`, error.message);
                // ✅ Règle S6535 corrigée : Suppression de l'antislash d'échappement inutile devant le \$
                await pool.query(
                    "UPDATE abonnements SET statut_abonnement = 'erreur_compilation' WHERE web_fingerprint = $1",
                    [web_fingerprint]
                );
                return;
            }

            const apkDownloadUrl = `http://192.168.1.100:5000/downloads/apks/genzo_pos_${web_fingerprint}.apk`;
            
            // ✅ Règle S6535 corrigée & S1481/S1854 résolues : Utilisation de la variable dans le log de succès
            await pool.query(
                "UPDATE abonnements SET statut_abonnement = 'pret_pour_telechargement' WHERE web_fingerprint = $1",
                [web_fingerprint]
            );
            console.log(`✨ [COMPILER SUCCESS] APK configurée et compilée avec succès. Lien : ${apkDownloadUrl}`);
        });

        return res.status(202).json({
            success: true,
            message: "Génération de l'APK personnalisée initiée. Verrous de plan injectés."
        });

    } catch (err) {
        console.error("🛑 [BACKEND EXCEPTION] Erreur :", err.message);
        return res.status(500).json({ success: false, message: "Échec interne de préparation du binaire." });
    }
};
