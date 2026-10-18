// path: backend/routes/users.route.js
const express = require('express');
const router = express.Router();
const usersController = require('../controllers/users.controller.js');

/**
 * @route   GET /api/v1/users
 * @desc    Extraire l'enceinte de sécurité utilisateur (RBAC) pour le POS local
 * @access  Public / POS Sync Auth
 */
router.get('/', usersController.getAllUsersByTenant);

module.exports = router;
