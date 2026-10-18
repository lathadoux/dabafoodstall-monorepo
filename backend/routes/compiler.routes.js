// path: backend/routes/compiler.routes.js
const express = require('express');
const router = express.Router();
const compilerController = require('../controllers/compiler.controller');

// Sécurisé en interne ou déclenché par la passerelle de paiement
router.post('/build-apk', compilerController.triggerApkCompilation);

module.exports = router;
