// path: backend/controllers/sync.controller.js
const pool = require('../config/database');

/**
 * 📥 COLLECTEUR CENTRAL : Réceptionne et stocke le rapport scellé #DABA_SYNC_PUSH_V1
 * Route: POST /api/v1/sync/upload-session
 */
exports.uploadClosedSession = async (req, res) => {
    const payloadComplet = req.body;

    // 1. Validation de l'en-tête du protocole applicatif mobile
    // 🔑 SYNTAXE ÉPURÉE ET CONCISE (Optional Chaining)
    if (payloadComplet?.protocol_version !== 'DABA_SYNC_PUSH_V1') {
        return res.status(400).json({
            success: false,
            message: "Protocole de synchronisation invalide ou obsolète."
        });
    }

    // 2. Extraction chirurgicale du bloc d'authentification et de traçabilité RH
    const { metadata } = payloadComplet;
    if (!metadata) {
        return res.status(400).json({
            success: false,
            message: "Bloc 'metadata' racine introuvable dans le payload."
        });
    }

    const {
        tenant_id,
        id_pos,
        device_fingerprint,
        id_session_local,
        cloture_par_user_id,
        date_cloture_locale
    } = metadata;

    // Garde-fou de gouvernance multi-tenant et multi-POS
    if (!tenant_id || !id_pos || !device_fingerprint || !id_session_local || !cloture_par_user_id || !date_cloture_locale) {
        return res.status(422).json({
            success: false,
            message: "Paramètres d'identification multi-POS ou traçabilité RH manquants."
        });
    }

    const client = await pool.connect();

    try {
        console.log(`📡 [API Sync Z] Ingestion du rapport Z pour le Tenant ${tenant_id}, POS ${id_pos}, Appareil ${device_fingerprint}...`);

        // 3. Insertion atomique en une seule requête SQL performante grâce au type JSONB
        const queryText = `
            INSERT INTO cloud_sync_sessions_z (
                tenant_id, 
                id_pos, 
                device_fingerprint, 
                id_session_local, 
                cloture_par_user_id, 
                date_cloture_locale, 
                payload_complet_jsonb
            ) VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id_sync_cloud, date_reception_cloud;
        `;

        const values = [
            tenant_id,
            id_pos,
            device_fingerprint,
            id_session_local,
            cloture_par_user_id,
            date_cloture_locale,
            JSON.stringify(payloadComplet) // Stockage binaire décomposé ultra-rapide
        ];

        const result = await client.query(queryText, values);
        const { id_sync_cloud, date_reception_cloud } = result.rows[0];

        console.log(`✅ [API Sync Z] Succès. Session locale #${id_session_local} scellée sous l'ID cloud #${id_sync_cloud}.`);

        // 4. Renvoi du drapeau 'success: true' attendu par le RemoteApiSource de l'application Flutter
        return res.status(201).json({
            success: true,
            message: "Rapport de clôture de caisse Z scellé et consolidé sur le Cloud.",
            idSessionCentrale: id_sync_cloud,
            received_at: date_reception_cloud
        });

    } catch (error) {
        // 5. Gestion spécifique des clés dupliquées (Code d'erreur PostgreSQL 23505)
        if (error.code === '23505') {
            console.warn(`⚠️ [API Sync Z] Doublon détecté pour le terminal ${device_fingerprint} (Session #${id_session_local}).`);
            return res.status(409).json({
                success: false,
                message: `Erreur d'intégrité : Le rapport de clôture pour cette session de caisse a déjà été synchronisé.`
            });
        }

        console.error("🛑 [API Sync Z Erreur] Échec critique d'écriture PostgreSQL :", error.message);
        return res.status(500).json({
            success: false,
            message: "Échec critique du traitement de stockage du rapport de clôture.",
            error_details: error.message
        });
    } finally {
        // Libération systématique du connecteur vers le pool pour éviter le gel du serveur
        client.release();
    }
};

/**
 * ⬇️ EXTRACTEUR DELTA : Compile le catalogue sur-mesure (Différentiel) #MIGRATION_NATIVE_DABA_V2
 * Route: GET /api/v1/sync/import
 */
exports.importDeltaCatalog = async (req, res) => {
    // 🛡️ SÉCURITÉ ABSOLUE : Les valeurs proviennent du middleware après vérification matérielle
    const id_tenant = req.terminal.id_tenant; 
    const nom_pos = req.terminal.nom_pos;     
    const { last_sync } = req.query; // ex: ?last_sync=2026-10-14 10:00:00

    const client = await pool.connect();

    try {
        // 1. VÉRIFICATION SOUVERAINE DE L'ABONNEMENT ET DES DROITS DU TENANT
        const abonnementQuery = await client.query(
            `SELECT a.date_fin, a.statut_activation, p.option_backoffice 
             FROM public.abonnements a
             JOIN public.plans_abonnement p ON a.plan_id = p.plan_id
             WHERE a.tenant_id = $1`,
            [id_tenant]
        );

        if (abonnementQuery.rows.length === 0) {
            return res.status(403).json({ 
                success: false, 
                error: "Accès refusé : Aucun abonnement configuré pour ce terminal." 
            });
        }

        const { date_fin, statut_activation, option_backoffice } = abonnementQuery.rows[0];
        const isExpired = new Date(date_fin) < new Date();

        if (isExpired || !statut_activation || !option_backoffice) {
            return res.status(402).json({ 
                success: false, 
                error: "Accès refusé : Option BackOffice non souscrite ou expirée." 
            });
        }

        // 2. FILTRE TEMPOREL DELTA
        // Si l'application mobile n'envoie aucune date, on prend la date d'origine (1970) pour tout descendre
        const syncTime = last_sync || '1970-01-01 00:00:00';
        console.log(`📡 [API Sync Delta] Extraction du catalogue pour le Tenant ${id_tenant} (Modifications depuis ${syncTime})...`);

        // Extraction des familles associées modifiées ou créées après last_sync
        const famillesQuery = await client.query(
            `SELECT id_famille, id_tenant, nom_famille, type_famille 
             FROM familles 
             WHERE id_tenant = $1 AND updated_at > $2 ORDER BY id_famille ASC`,
            [id_tenant, syncTime]
        );

        // Extraction des articles associés modifiés ou créés après last_sync
        const articlesQuery = await client.query(
            `SELECT id_article, id_tenant, id_famille, nom_article, type_article, prix_unitaire, unite_mesure 
             FROM articles 
             WHERE id_tenant = $1 AND updated_at > $2 ORDER BY id_article ASC`,
            [id_tenant, syncTime]
        );

        console.log(`✅ [API Sync Delta] ${famillesQuery.rows.length} familles et ${articlesQuery.rows.length} articles extraits.`);

        // 3. Envoi du package calé sur les clés attendues par Flutter
        return res.status(200).json({
            success: true,
            tenant_id: id_tenant,
            business_name: nom_pos,
            server_timestamp: new Date().toISOString(), // Nouvelle horloge serveur de référence pour SQLite
            familles: famillesQuery.rows,
            articles: articlesQuery.rows
        });

    } catch (err) {
        console.error('🛑 [API Sync Delta Erreur] :', err.message);
        return res.status(500).json({ 
            success: false, 
            error: "Échec de compilation du catalogue différentiel PostgreSQL.",
            details: err.message
        });
    } finally {
        client.release(); // Libération systématique
    }
};
