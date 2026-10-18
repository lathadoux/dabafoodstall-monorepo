// path: backend/routes/sync.routes.js
const express = require('express');
const router = express.Router();
const syncController = require('../controllers/sync.controller');
const verifyTerminalAndUser = require('../middleware/tenantAuth'); // 🔑 Bouclier matériel unifié

// ⬆️ AXE REMONTÉE (UPLOAD)
// Centralise et scelle le dictionnaire JSON de clôture Z
router.post('/upload-session', verifyTerminalAndUser, syncController.uploadClosedSession);

// ⬇️ AXE DESCENTE (DOWNLOAD - DELTA OPTIMISÉ)
// Extrait le catalogue différentiel calé sur l'horloge du serveur
router.get('/import', verifyTerminalAndUser, syncController.importDeltaCatalog);

module.exports = router;
