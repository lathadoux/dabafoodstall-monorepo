const pool = require('../config/database'); // 🔑 ALIGNEMENT : Utilisation du Pool centralisé du conteneur
const jwt = require('jsonwebtoken');
const crypto = require('node:crypto');

/**
 * 💥 ÉTAPE 2 : INITIALISATION DU PAIEMENT (DÉCLENCHEMENT POP-UP MOBILE - STK PUSH)
 */
exports.initiateMobilePayment = async (req, res) => {
  const { id_abonnement, telephone_payeur, operateur, mois_prolongation } = req.body;

  if (!id_abonnement || !telephone_payeur || !operateur) {
    return res.status(400).json({ status: 'error', message: 'Paramètres de paiement incomplets.' });
  }

  try {
    const mois = Number.parseInt(mois_prolongation, 10) || 1;
    const orderId = `DABA-${Date.now()}-${crypto.randomInt(100, 999)}`;

    const planQuery = await pool.query(
      `SELECT p.tarif_mensuel, p.nom_plan 
       FROM public.abonnements a
       JOIN public.plans_abonnement p ON a.plan_id = p.plan_id
       WHERE a.id_abonnement = $1`,
      [id_abonnement]
    );

    if (planQuery.rows.length === 0) {
      return res.status(404).json({ status: 'error', message: 'Abonnement ou plan de tarification associé introuvable.' });
    }

    const { tarif_mensuel } = planQuery.rows[0];
    const montantTotal = mois * Number.parseFloat(tarif_mensuel);

    console.log(`📡 [API Agrégateur] Envoi STK Push ID [${orderId}] au numéro ${telephone_payeur} (${operateur}) pour ${montantTotal} F CFA`);
// 🔑 LE SÉSAME INFRA : Mémorisation automatique de l'ID vivant pour le simulateur
    req.app.set('last_active_order', {
        order_id: orderId,
        id_abonnement: id_abonnement,
        operateur: operateur,
        mois_prolongation: String(mois)
    });

    // Aligné sur la colonne statut_abonnement de votre schéma réel
    await pool.query(
      "UPDATE abonnements SET statut_abonnement = 'en_attente' WHERE id_abonnement = $1",
      [id_abonnement]
    );

    return res.status(200).json({
      status: 'success',
      message: 'Demande de paiement envoyée. Saisissez votre code secret PIN sur votre téléphone.',
      order_id: orderId,
      montant_facture: montantTotal
    });

  } catch (error) {
    console.error("❌ Erreur initiation paiement :", error.message);
    return res.status(500).json({ status: 'error', message: "Impossible d'initier la transaction Mobile Money." });
  }
};

/**
 * 🟠 ÉTAPE 3 : RECONNAISSANCE / RECHERCHE DE L'ABONNEMENT POUR PAIEMENT
 */
exports.searchAbonnementForPayment = async (req, res) => {
  const { code_court } = req.query;
  const deviceDfp = req.headers['x-device-dfp'];

  try {
    let query = "";
    let params = [];

    if (deviceDfp) {
      query = `SELECT a.id_abonnement, a.tenant_id, a.date_expiration_cloud AS date_fin, a.statut_abonnement AS statut_activation, p.nom_plan, p.tarif_mensuel
               FROM public.abonnements a 
               JOIN public.plans_abonnement p ON a.plan_id = p.plan_id
               WHERE a.device_fingerprint = $1`;
      params = [deviceDfp];
    } 
    else if (code_court) {
      query = `SELECT a.id_abonnement, a.tenant_id, a.date_expiration_cloud AS date_fin, a.statut_abonnement AS statut_activation, p.nom_plan, p.tarif_mensuel
               FROM public.abonnements a 
               JOIN public.plans_abonnement p ON a.plan_id = p.plan_id
               WHERE a.code_activation_court = $1`;
      params = [code_court.trim()];
    } else {
      return res.status(400).json({ status: 'error', message: 'Identifiant multi-tenant ou code court manquant.' });
    }

    const result = await pool.query(query, params);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ status: 'error', message: 'Aucun abonnement trouvé pour cet identifiant.' });
    }

    return res.status(200).json({ status: 'success', data: result.rows[0] });

  } catch (err) {
    console.error("❌ Erreur recherche paiement :", err.message);
    return res.status(500).json({ status: 'error', message: "Erreur d'infrastructure de facturation." });
  }
};

/**
 * 🟢 ÉTAPE 4 : CONFIRMATION DU RÈGLEMENT MANUEL ET CALCUL DU TOKEN
 */
exports.confirmPaymentAndRenew = async (req, res) => {
  const { id_abonnement, reference_operateur, operateur, mois_prolongation, order_id } = req.body;

  try {
    const mois = Number.parseInt(mois_prolongation, 10) || 1;
    
    const planQuery = await pool.query(
      `SELECT p.tarif_mensuel FROM public.abonnements a 
       JOIN public.plans_abonnement p ON a.plan_id = p.plan_id WHERE a.id_abonnement = $1`,
      [id_abonnement]
    );
    
    const tarifMensuel = planQuery.rows[0]?.tarif_mensuel || 5000;
    const montantVerse = mois * Number.parseFloat(tarifMensuel);

    // 🔑 FIX SÉMANTIQUE POSTGRESQL : Aligné sur date_expiration_cloud, statut_abonnement et date_activation_cloud
    const updateQuery = `
      UPDATE abonnements 
      SET date_expiration_cloud = date_expiration_cloud + INTERVAL '1 month' * $1,
          statut_abonnement = 'actif',
          date_activation_cloud = CURRENT_TIMESTAMP
      WHERE id_abonnement = $2
      RETURNING date_expiration_cloud AS date_fin, tenant_id;
    `;
    const result = await pool.query(updateQuery, [mois, id_abonnement]);

    if (result.rows.length === 0) {
      return res.status(404).json({ status: 'error', message: 'Abonnement introuvable.' });
    }

    const updated = result.rows[0];

    await pool.query(
      "INSERT INTO paiements_licences (id_abonnement, reference_operateur, operateur_utilise, montant_verse, mois_prolongation) VALUES ($1, $2, $3, $4, $5)",
      [id_abonnement, reference_operateur, operateur, montantVerse, mois]
    );

    const extensionToken = jwt.sign({
      tenant_id: updated.tenant_id,
      new_expiration: updated.date_fin
    }, process.env.JWT_SECRET || "DABA_SUPER_SECRET_KEY_2026_IVORY_COAST", { expiresIn: '1d' });

    const io = req.app.get('socketio');
    if (io && order_id) {
      io.to(`room_${order_id}`).emit('payment_update', {
        order_id: order_id,
        status: 'SUCCESS',
        new_expiration: updated.date_fin
      });
    }

    return res.status(200).json({
      status: 'success',
      message: `Paiement ${operateur} validé. Licence prolongée de ${mois} mois.`,
      new_expiration: updated.date_fin,
      prolongation_token: extensionToken
    });

  } catch (err) {
    console.error("❌ Erreur validation paiement :", err.message);
    return res.status(500).json({ status: 'error', message: 'Échec de traitement du paiement.' });
  }
};

/**
 * 🔒 ÉTAPE 6 : WEBHOOK DE L'OPÉRATEUR (TRAITEMENT DU MESSAGE DE CRÉDIT AUTOMATIQUE)
 * Alignement strict sur le schéma physique PostgreSQL (statut_abonnement & date_expiration_cloud)
 */
exports.handleOperatorWebhook = async (req, res) => {
  const { status, transaction_id, order_id, id_abonnement, operateur, mois_prolongation } = req.body;

  if (status !== 'ACCEPTED' && status !== 'SUCCESS') {
    return res.status(200).json({ message: 'Notification ignorée (Transaction non aboutie).' });
  }

  try {
    const mois = Number.parseInt(mois_prolongation, 10) || 1;

    const planQuery = await pool.query(
      `SELECT p.tarif_mensuel FROM public.abonnements a 
       JOIN public.plans_abonnement p ON a.plan_id = p.plan_id WHERE a.id_abonnement = $1`,
      [id_abonnement]
    );
    
    if (planQuery.rows.length === 0) {
      return res.status(404).json({ status: 'error', message: 'Abonnement introuvable pour le calcul du tarif.' });
    }

    const tarifMensuel = planQuery.rows[0]?.tarif_mensuel || 5000;

    // 🔑 ALIGNEMENT SCHÉMA : Utilisation exclusive de date_expiration_cloud, statut_abonnement et date_activation_cloud
    const updateQuery = `
      UPDATE abonnements 
      SET date_expiration_cloud = date_expiration_cloud + INTERVAL '1 month' * $1,
          statut_abonnement = 'actif',
          date_activation_cloud = CURRENT_TIMESTAMP
      WHERE id_abonnement = $2
      RETURNING date_expiration_cloud AS date_fin, tenant_id;
    `;
    const result = await pool.query(updateQuery, [mois, id_abonnement]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Abonnement introuvable lors de la prolongation.' });
    }

    const updated = result.rows[0];
    console.log(`🎉 [Webhook] Traitement de la commande Mobile Money [${order_id}] aboutie.`);

    // Enregistrement comptable de la transaction dans le journal des licences
    await pool.query(
      "INSERT INTO paiements_licences (id_abonnement, reference_operateur, operateur_utilise, montant_verse, mois_prolongation) VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING",
      [id_abonnement, transaction_id, operateur, mois * Number.parseFloat(tarifMensuel), mois]
    );

    // 🔌 ÉMISSION TEMPS RÉEL MULTI-CANAUX : Alerte la commande ET l'abonnement global
    const io = req.app.get('socketio');
    if (io) {
      const updatePayload = {
        order_id: order_id,
        status: status,
        id_abonnement: id_abonnement,
        new_expiration: updated.date_fin
      };

      // 1. Canal spécifique à l'ordre d'origine
      if (order_id) {
        io.to(`room_${order_id}`).emit('payment_update', updatePayload);
      }
      
      // 2. 🔑 CANAL DE SECOURS : Immunise l'IHM contre les erreurs de saisie d'ID dans le simulateur
      if (id_abonnement) {
        io.to(`room_sub_${id_abonnement}`).emit('payment_update', updatePayload);
      }
    }

    return res.status(200).json({ status: 'success', message: 'Webhook traité, abonnement reconduit automatiquement.' });

  } catch (error) {
    console.error("❌ Erreur critique Webhook :", error.message);
    return res.status(500).json({ message: 'Erreur interne de traitement comptable.' });
  }
};

/**
 * 🔍 ROUTE INTRADECK : Récupération automatique de la dernière session de test active
 */
exports.getLastActiveOrder = (req, res) => {
  const lastOrder = req.app.get('last_active_order');
  if (!lastOrder) {
    return res.status(404).json({ status: 'error', message: 'Aucune session de paiement en attente sur l IHM.' });
  }
  return res.status(200).json({ status: 'success', data: lastOrder });
};

