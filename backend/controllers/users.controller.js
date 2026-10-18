// path: backend/controllers/users.controller.js
const pool = require('../config/database'); // Votre connecteur pg.Pool standard

/**
 * Récupère l'intégralité des utilisateurs d'un Tenant (Entreprise)
 * Route : GET /api/v1/users?tenantId=1
 */
exports.getAllUsersByTenant = async (req, res) => {
    try {
        const { tenantId } = req.query;

        // Validation stricte du paramètre de cloisonnement multi-tenant
        if (!tenantId) {
            return res.status(400).json({
                success: false,
                message: "❌ Le paramètre 'tenantId' est obligatoire pour filtrer les profils."
            });
        }

        // Requête d'audit : on extrait l'identifiant, le nom, le rôle et le code PIN unique
        const queryText = `
            SELECT id_user, id_tenant, nom_user, role_user, pin_user 
            FROM users 
            WHERE id_tenant = $1
            ORDER BY role_user ASC, nom_user ASC
        `;

        const { rows } = await pool.query(queryText, [Number.parseInt(tenantId, 10)]);

        // Réponse standardisée pour le SyncService du terminal mobile
        return res.status(200).json({
            success: true,
            count: rows.length,
            timestamp: new Date().toISOString(),
            users: rows
        });

    } catch (error) {
        // 🚨 LOG DE PRODUCTION : Affiche la cause réelle dans votre console de commande
        console.error("🛑 [Server Error - GetUsers] DETAILS :", error.message);
        
        return res.status(500).json({
            success: false,
            message: "Erreur interne lors de l'extraction des profils utilisateurs PostgreSQL.",
            error_details: error.message // 🛠️ FIX DIAGNOSTIC : Renvoie la vraie erreur SQL (ex: "relation users does not exist")
        });
    }
};
