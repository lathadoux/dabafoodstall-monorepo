// path: backend/controllers/license.controller.js
const crypto = require('node:crypto'); // ✅ Règle S7772 corrigée
const pool = require('../config/database');

/**
 * 🛡️ CONFORME SONARLINT : Générateur de Code Court Unique à 3x4 chiffres
 */
function createCryptoShortCode() {
  const block1 = crypto.randomInt(1000, 10000); // Format 3x4 : 1000 à 9999
  const block2 = crypto.randomInt(1000, 10000);
  const block3 = crypto.randomInt(1000, 10000);
  return `${block1}-${block2}-${block3}`;
}

/**
 * 📡 ÉTAPE 1 : ENRÔLEMENT TERRAIN CO-SIGNÉ PAR LE COMMERCIAL (7788)
 */
exports.commercialCosign = async (req, res) => {
    const {
        pin_commercial,
        pos_raison_sociale,
        whatsapp_number,
        client_email,
        commune,
        quartier,
        adresse_geographique,
        gps_coordinates,
        client_civilite,
        client_nom,
        client_prenom,
        date_naissance,
        type_pos,
        web_fingerprint
    } = req.body;

    console.log("📡 [DABA-DEBUG-BACK 1] Requête d'enrôlement reçue par la Gateway.");
    
    if (!pin_commercial) {
        return res.status(400).json({ status: 'error', message: 'Signature commerciale requise.' });
    }

    const client = await pool.connect();

    try {
        await client.query('BEGIN');
        console.log("⚡ [DABA-DEBUG-BACK 2] Transaction atomique BEGIN initiée.");

        // 1. RECHERCHE DU PROFIL RH COMMERCIAL
        const userQuery = await client.query(
            `SELECT id_user, id_tenant, nom_user, role_user FROM users WHERE pin_user = $1 LIMIT 1`,
            [pin_commercial.trim()]
        );

        if (userQuery.rows.length === 0) {
            await client.query('ROLLBACK');
            console.log("🛑 [DABA-DEBUG-BACK 3] Échec : Code PIN commercial inexistant.");
            return res.status(401).json({ status: 'error', message: 'INVALID_PIN' });
        }

        const commercial = userQuery.rows[0];
        console.log(`⚡ [DABA-DEBUG-BACK 4] Utilisateur identifié : ${commercial.nom_user} (${commercial.role_user})`);

        if (commercial.role_user !== 'commercial' && commercial.role_user !== 'super_admin') {
            await client.query('ROLLBACK');
            console.log("🛑 [DABA-DEBUG-BACK 5] Échec : Droits de signature insuffisants.");
            return res.status(403).json({ status: 'error', message: 'UNAUTHORIZED_ROLE' });
        }

        // 2. INSERTION DU TENANT
        const tenantInsert = await client.query(
            "INSERT INTO tenants (nom_business) VALUES ($1) RETURNING id_tenant",
            [pos_raison_sociale]
        );
        const idTenantGenere = tenantInsert.rows[0].id_tenant;
        console.log(`⚡ [DABA-DEBUG-BACK 6] Table 'tenants' alimentée. ID alloué : ${idTenantGenere}`);

        // 3. INSERTION DU POINT DE VENTE (POS)
        const posInsert = await client.query(
            "INSERT INTO points_de_vente (id_tenant, nom_pos, type_pos) VALUES ($1, $2, $3) RETURNING id_pos",
            [idTenantGenere, pos_raison_sociale, type_pos === 'general' ? 'general' : 'garba_stall']
        );
        const idPosGenere = posInsert.rows[0].id_pos;
        console.log(`⚡ [DABA-DEBUG-BACK 7] Table 'points_de_vente' alimentée. ID alloué : ${idPosGenere}`);

        // 4. CALCUL DU CODE 3x4 ET EXPIRATION INITIALE
        const dateExpiration = new Date();
        dateExpiration.setDate(dateExpiration.getDate());
        
        const codeActivationCourt = createCryptoShortCode();
        const termPhoneNumberFake = "+225" + String(crypto.randomInt(10000000, 99999999));
        
        let dateNaissanceFormatee = null;
        if (date_naissance && date_naissance.trim() !== "") {
            const parsedDate = new Date(date_naissance);
            if (!Number.isNaN(parsedDate.getTime())) { // ✅ Règle S7773 corrigée
                dateNaissanceFormatee = parsedDate.toISOString().split('T')[0];
            }
        }

        // 5. INJECTION DE L'ABONNEMENT CLOUD V2
        const abonnementInsertQuery = `
            INSERT INTO abonnements (
                tenant_id, pos_id, plan_id, web_fingerprint, pos_raison_sociale, term_phone_number,
                date_expiration_cloud, statut_abonnement, client_email, whatsapp_number,
                commune, quartier, adresse_geographique, gps_coordinates, client_civilite, client_nom,
                client_prenom, date_naissance, type_pos, code_activation_court
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'en_attente', $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
            RETURNING id_abonnement;
        `;

        await client.query(abonnementInsertQuery, [
            idTenantGenere,
            idPosGenere,
            2,
            web_fingerprint,
            pos_raison_sociale,
            termPhoneNumberFake,
            dateExpiration,
            client_email,
            whatsapp_number,
            commune,
            quartier,
            adresse_geographique,
            gps_coordinates,
            client_civilite,
            client_nom,
            client_prenom,
            dateNaissanceFormatee,
            type_pos,
            codeActivationCourt
        ]);

        await client.query('COMMIT');
        console.log(`✅ [DABA-DEBUG-BACK 8] Écriture scellée avec succès. Code court : ${codeActivationCourt}`);

        return res.status(201).json({
            status: 'success',
            message: `Enrôlement validé par ${commercial.nom_user}. Catalogue initialisé.`,
            code_activation: codeActivationCourt
        });

    } catch (error) {
        await client.query('ROLLBACK');
        console.error("🛑 [DABA-DEBUG-BACK 9] CRASH CRITIQUE POSTGRESQL DETECTÉ :");
        console.error("👉 Message :", error.message);
        console.error("👉 Code Erreur :", error.code);
        console.error("👉 Détail :", error.detail);
        
        return res.status(500).json({ status: 'error', message: error.message, code: error.code });
    } finally {
        client.release();
    }
};

/**
 * 🔒 ÉTAPE 2 : PREMIER BOOT DU TERMINAL MOBILE (SCELLAGE MATÉRIEL DFP)
 */
exports.commercialCosignEnrollment = async (req, res) => {
    const { id_abonnement, device_fingerprint } = req.body;

    if (!id_abonnement || !device_fingerprint) {
        return res.status(400).json({ success: false, message: "Payload d'enrôlement matériel incomplet." });
    }

    try {
        // ✅ Règle S7773 corrigée (Number.parseInt)
        const idAbonnementNumerique = Number.parseInt(id_abonnement, 10);

        if (Number.isNaN(idAbonnementNumerique)) { // ✅ Règle S7773 corrigée (Number.isNaN)
            return res.status(422).json({ success: false, message: "Format de l'identifiant d'abonnement invalide." });
        }

        console.log(`🛡️ [Sync Engine Cloud] Tentative de liaison matérielle pour l'abonnement #${idAbonnementNumerique}...`);

        const enrollQuery = `
            UPDATE public.abonnements 
            SET device_fingerprint = $1,
                statut_abonnement = 'actif',
                date_activation_cloud = CURRENT_TIMESTAMP
            WHERE id_abonnement = $2
            RETURNING date_expiration_cloud;
        `;

        const result = await pool.query(enrollQuery, [device_fingerprint, idAbonnementNumerique]);

        if (result.rows.length === 0) {
            return res.status(404).json({ success: false, message: "Enrôlement impossible : Abonnement introuvable." });
        }

        return res.status(200).json({
            success: true,
            message: "Enrôlement matériel validé et terminal scellé sur le Cloud.",
            activation_timestamp: new Date().toISOString(),
            expires_at: result.rows[0].date_expiration_cloud
        });

    } catch (error) {
        console.error("🛑 [API Cosign Erreur Materialization] :", error.message);
        return res.status(500).json({ success: false, message: "Échec critique de l'enrôlement matériel." });
    }
};

/**
 * 🔍 ÉTAPE 3 : PING / VÉRIFICATION FLASH DE LICENCE COUCHES MOBILES
 */
exports.checkLicenseStatus = async (req, res) => {
  const device_fingerprint = req.headers['x-device-dfp'];

  if (!device_fingerprint) {
    return res.status(400).json({ status: 'error', message: 'Identification matérielle (DFP) absente.' });
  }

  try {
    const result = await pool.query(
      'SELECT date_expiration_cloud, statut_abonnement FROM abonnements WHERE device_fingerprint = $1',
      [device_fingerprint]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ status: 'error', message: 'Aucun abonnement trouvé.' });
    }

    const { date_expiration_cloud, statut_abonnement } = result.rows[0];
    const now = new Date();

    if (new Date(date_expiration_cloud) <= now) {
      if (statut_abonnement !== 'bride') {
        await pool.query("UPDATE abonnements SET statut_abonnement = 'bride' WHERE device_fingerprint = $1", [device_fingerprint]);
      }
      return res.status(402).json({
        status: 'restricted',
        message: 'Abonnement expiré sur le serveur.',
        date_expiration: date_expiration_cloud
      });
    }

    return res.json({ status: 'active', date_expiration: date_expiration_cloud });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: 'Erreur interne de vérification.' });
  }
};

/**
 * 📲 EXCLUSIF FLUTTER V2 : SCELLAGE ET ACTIVATION AUTOMATIQUE DE L'APK PRÉCOMPILÉE
 */
exports.activatePrecompiled = async (req, res) => {
    const { enrolment_fingerprint, device_fingerprint } = req.body;

    if (!enrolment_fingerprint) {
        return res.status(400).json({ 
            success: false, 
            message: "Empreinte d'enrôlement (identité APK) absente." 
        });
    }

    const finalDeviceFingerprint = device_fingerprint || enrolment_fingerprint;

    try {
		console.log(📡 [Sync Engine Cloud] Demande d'activation automatique pour : ${enrolment_fingerprint});
		const activationQuery = UPDATE public.abonnements  SET device_fingerprint = $1, statut_abonnement = 'actif', date_activation_cloud = CURRENT_TIMESTAMP WHERE web_fingerprint = $2 RETURNING id_abonnement, date_expiration_cloud, type_pos, pos_raison_sociale;;
		const result = await pool.query(activationQuery, [finalDeviceFingerprint, enrolment_fingerprint]);
		if (result.rows.length === 0) {
		return res.status(404).json({
		success: false,
		message: "Liaison impossible : aucune préinscription correspondante sur le serveur."
		});
		}
		const abonnement = result.rows[0];
		return res.status(200).json({
		success: true,
		message: "Application activée et terminal scellé avec succès.",
		id_abonnement: abonnement.id_abonnement,
		expiry_date: abonnement.date_expiration_cloud,
		pos_type: abonnement.type_pos,
		activation_timestamp: new Date().toISOString()
		});
		} catch (error) {
		// ✅ Règle S2486 corrigée : L'exception est logguée et traitée via le retour HTTP 500
		console.error("🛑 [API Precompiled Activation Erreur] :", error.message);
		return res.status(500).json({
		success: false,
		message: "Échec critique lors du scellage automatique de la licence mobile."
		});
	}
};