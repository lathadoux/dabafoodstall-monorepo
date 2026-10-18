// path: backend/routes/sync.routes.js
const express = require('express');
const router = express.Router();
const pool = require('../config/database'); // Connexion au pool PostgreSQL du conteneur
const syncController = require('../controllers/sync.controller');
const verifyTerminalAndUser = require('../middleware/tenantAuth'); // 🔑 Intégration du bouclier unifié

/**
 * 📥 POST /api/v1/sync/upload-session
 * Centralise et scelle le dictionnaire JSON de clôture Z (#DABA_SYNC_PUSH_V1)
 * Doublement sécurisé par IMEI/Fingerprint matériel et jeton utilisateur JWT
 */
router.post('/upload-session', verifyTerminalAndUser, syncController.uploadClosedSession);

/**
 * 📥 GET /api/v1/sync/import
 * Extrait dynamiquement le catalogue filtré sur mesure pour l'étal demandeur
 * #MIGRATION_NATIVE_DABA_V1
 */
router.get('/import', verifyTerminalAndUser, async (req, res) => {
  // 🛡️ SÉCURITÉ ABSOLUE : Les valeurs proviennent du middleware après vérification matérielle en base
  const id_tenant = req.terminal.id_tenant; // Plus de bypass en dur !
  const nom_pos = req.terminal.nom_pos;     // Récupère le nom officiel enregistré (ex: Garba de la Citadelle)

  try {
    console.log(`📡 [API Sync Production] Extraction du catalogue PostgreSQL complet pour le Tenant ${id_tenant}...`);

    // 1. Extraction de toutes les familles associées à ce Tenant spécifique via la clé validée
    const famillesQuery = await pool.query(
      'SELECT id_famille, id_tenant, nom_famille, type_famille FROM familles WHERE id_tenant = $1 ORDER BY id_famille ASC',
      [id_tenant]
    );

    // 2. Extraction de tous les articles associés à ce Tenant avec leurs prix
    const articlesQuery = await pool.query(
      'SELECT id_article, id_tenant, id_famille, nom_article, type_article, prix_unitaire, unite_mesure FROM articles WHERE id_tenant = $1 ORDER BY id_article ASC',
      [id_tenant]
    );

    console.log(`✅ [API Sync] ${famillesQuery.rows.length} familles et ${articlesQuery.rows.length} articles extraits avec succès.`);

    // 3. Envoi du package de données calé sur les clés attendues par l'application Flutter
    return res.status(200).json({
      success: true,
      tenant_id: id_tenant,
      business_name: nom_pos,
      familles: famillesQuery.rows,
      articles: articlesQuery.rows
    });

  } catch (err) {
    console.error('🛑 [API Sync Erreur Production] :', err.message);
    return res.status(500).json({ 
      success: false, 
      error: "Échec de compilation du catalogue de production PostgreSQL.",
      details: err.message
    });
  }
});




module.exports = router;
