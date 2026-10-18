// path: backend/routes/license.routes.js
const express = require('express');
const router = express.Router();
const licenseController = require('../controllers/license.controller');

// 🔒 Points d'accès d'infrastructure épurés V2
router.post('/commercial-cosign', licenseController.commercialCosign);
router.post('/commercial-cosign-enrollment', licenseController.commercialCosignEnrollment);
router.get('/check-status', licenseController.checkLicenseStatus);


// 📲 Nouvelle route pour l'activation et le scellage automatique de l'APK Flutter
router.post('/activate-precompiled', licenseController.activatePrecompiled);

module.exports = router;
