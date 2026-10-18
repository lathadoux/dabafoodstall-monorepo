// path: backend/middlewares/tenantAuth.js
const pool = require('../config/database');
const jwt = require('jsonwebtoken'); // 🔑 AJOUT CRITIQUE pour le contrôle utilisateur

/**
 * 🔒 MIDDLEWARE HOOK UNIQUE : Double Authentification Matérielle (IMEI/Fingerprint) & Logicielle (JWT)
 */
const verifyTerminalAndUser = async (req, res, next) => {
  // 1. Extraction des identifiants matériels
  const imei = req.headers['x-terminal-imei'] || req.headers['device-fingerprint'];
  if (!imei) {
    return res.status(401).json({ success: false, error: "Accès refusé. Identification matérielle manquante." });
  }

  // 2. Extraction sécurisée du jeton JWT avec le chaînage optionnel
  const authHeader = req.headers['authorization'];
  const token = authHeader?.startsWith('Bearer ') ? authHeader.split(' ')[1] : null;

  if (!token) {
    return res.status(401).json({ success: false, error: "Accès refusé. Jeton utilisateur JWT manquant." });
  }
  

  try {
    // 3. VÉRIFICATION PHYSIQUE DU TERMINAL DANS LA BASE CLOUD
    const terminalQuery = `
      SELECT t.id_terminal, t.id_tenant, t.id_pos, p.nom_pos
      FROM terminaux t
      JOIN points_de_vente p ON t.id_pos = p.id_pos
      WHERE t.imei_appareil = $1
    `;

    const terminalResult = await pool.query(terminalQuery, [imei]);

    if (terminalResult.rows.length === 0) {
      return res.status(403).json({
        success: false,
        error: "Verrouillage Enseigne actif. Ce terminal matériel n'est pas autorisé."
      });
    }

    const terminalData = terminalResult.rows[0];

    // 4. VÉRIFICATION ET DÉCHIFFREMENT DU JETON JWT DE L'AUTEUR
    const secretKey = process.env.JWT_SECRET || 'DABA_SUPER_SECRET_KEY_2026_IVORY_COAST';
    const decodedUser = jwt.verify(token, secretKey);

    // 5. 🛡️ LE GARDE-FOU ANTI-FRAUDE (CROSS-CHECK)
    // On vérifie que le gérant connecté appartient bien au même Tenant que la tablette matérielle
    if (decodedUser.id_tenant !== terminalData.id_tenant) {
      return res.status(403).json({
        success: false,
        error: "Violation de sécurité : L'utilisateur n'appartient pas à l'enseigne de ce terminal."
      });
    }

    // 6. INJECTION DU CONTEXTE GLOBAL UNIQUE DANS EXPRESS
    // Vos contrôleurs ont désormais accès à TOUT le périmètre validé
    req.terminal = {
      id_terminal: terminalData.id_terminal,
      id_tenant: terminalData.id_tenant,
      id_pos: terminalData.id_pos,
      nom_pos: terminalData.nom_pos
    };

    req.user = decodedUser; // Injecte l'utilisateur authentifié (contient l'id_user auteur)

    next(); // Double validation réussie, passage à la route métier d'ingestion Z
  } catch (err) {
    if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
      return res.status(403).json({ success: false, error: "Session expirée ou jeton JWT invalide." });
    }
    
    console.error('🛑 [Middleware Erreur Unifié] :', err.message);
    return res.status(500).json({ success: false, error: "Erreur serveur lors du contrôle de sécurité global." });
  }
};

module.exports = verifyTerminalAndUser;
