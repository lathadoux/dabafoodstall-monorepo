// routes/payment.routes.js
const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/payment.controller');

// Déclaration claire des deux points d'accès de l'IHM de paiement mobile
router.get('/search', paymentController.searchAbonnementForPayment);
router.post('/confirm', paymentController.confirmPaymentAndRenew);

// 🔑 ENTRAÎNEMENT DE LA MACHINERIE DE PAIEMENT SANS SAISIE MANUELLE
router.post('/initiate', paymentController.initiateMobilePayment);
router.post('/webhook', paymentController.handleOperatorWebhook); // Point d'entrée de l'opérateur Mobile Money

//ROUTE INTRADECK : Récupération automatique de la dernière session de test active
router.get('/last-order', paymentController.getLastActiveOrder);

module.exports = router;
