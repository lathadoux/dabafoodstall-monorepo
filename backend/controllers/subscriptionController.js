const db = require('../config/db');

/**
 * 1. FORMULAIRE DE GESTION (Exclusif au BackOffice Serveur)
 * Enregistre ou met à jour un abonnement en calculant automatiquement le prix
 */
exports.saveTenantSubscription = async (req, res) => {
    const { tenant_id, option_sauvegarde, option_backoffice, option_synchro_x_realtime, mois_duree } = req.body;

    if (!tenant_id || mois_duree === undefined) {
        return res.status(400).json({ error: "Champs obligatoires manquants." });
    }

    try {
        // Recherche automatique du plan correspondant à la combinaison exacte d'options
        const planQuery = `
            SELECT plan_id, tarif_mensuel, nom_plan 
            FROM public.plans_abonnement 
            WHERE option_sauvegarde = $1 
              AND option_backoffice = $2 
              AND option_synchro_x_realtime = $3;
        `;
        
        const planResult = await db.query(planQuery, [
            option_sauvegarde || false, 
            option_backoffice || false, 
            option_synchro_x_realtime || false
        ]);

        if (planResult.rows.length === 0) {
            return res.status(404).json({ 
                error: "Aucun tarif ne correspond à cette combinaison d'options dans la grille tarifaire." 
            });
        }

        const { plan_id, tarif_mensuel, nom_plan } = planResult.rows[0];
        const coutTotal = Number.parseFloat(tarif_mensuel) * Number.parseInt(mois_duree);

        // Calcul des dates de validité sur l'horloge immuable du serveur
        const dateDebut = new Date();
        const dateFin = new Date();
        dateFin.setMonth(dateFin.getMonth() + Number.parseInt(mois_duree));

        // Enregistrement ou mise à jour stricte (Multi-Tenant Guard)
        const upsertQuery = `
            INSERT INTO public.abonnements (tenant_id, plan_id, date_debut, date_fin, statut_activation, updated_at)
            VALUES ($1, $2, $3, $4, true, CURRENT_TIMESTAMP)
            ON CONFLICT (tenant_id) 
            DO UPDATE SET 
                plan_id = EXCLUDED.plan_id,
                date_debut = EXCLUDED.date_debut,
                date_fin = EXCLUDED.date_fin,
                statut_activation = true,
                updated_at = CURRENT_TIMESTAMP
            RETURNING abonnement_id, date_fin;
        `;

        const subscriptionResult = await db.query(upsertQuery, [tenant_id, plan_id, dateDebut, dateFin]);

        return res.status(200).json({
            message: "Abonnement enregistré avec succès.",
            tenant_id,
            plan_identifie: nom_plan,
            tarif_mensuel: `${tarif_mensuel} XOF`,
            facturation_totale: `${coutTotal} XOF`,
            expire_le: subscriptionResult.rows[0].date_fin
        });

    } catch (error) {
        console.error("Erreur lors de l'enregistrement de l'abonnement :", error);
        return res.status(500).json({ error: "Erreur interne lors du traitement du formulaire." });
    }
};

/**
 * 2. PAYLOAD DE DESCENTE (Flashage Caisse Mobile Flutter)
 * Renvoie l'état d'activation et les verrous de fonctionnalités pour SQLite
 */
exports.getFlashLicenseConfig = async (req, res) => {
    // Le tenant_id est extrait de manière sécurisée (via req.body ou req.tenant pour DABAPOS)
    const { tenant_id } = req.body; 

    if (!tenant_id) {
        return res.status(400).json({ error: "Identifiant de caisse (tenant_id) manquant." });
    }

    try {
        const licenseQuery = `
            SELECT a.date_fin, a.statut_activation,
                   p.option_sauvegarde, p.option_backoffice, p.option_synchro_x_realtime
            FROM public.abonnements a
            JOIN public.plans_abonnement p ON a.plan_id = p.plan_id
            WHERE a.tenant_id = $1;
        `;

        const result = await db.query(licenseQuery, [tenant_id]);

        if (result.rows.length === 0) {
            return res.status(403).json({
                status: "UNLICENSED",
                expires_at: "1970-01-01T00:00:00.000Z",
                features: { allow_backup: false, allow_backoffice: false, allow_realtime_x: false }
            });
        }

        const license = result.rows[0];
        const isExpired = new Date(license.date_fin) < new Date();

        // Si la licence est expirée ou désactivée manuellement depuis l'administration
        if (isExpired || !license.statut_activation) {
            return res.status(200).json({
                status: "EXPIRED",
                expires_at: license.date_fin,
                features: { allow_backup: false, allow_backoffice: false, allow_realtime_x: false }
            });
        }

        // Payload valide : les drapeaux sont descendus pour flasher l'état SQLite du mobile
        return res.status(200).json({
            status: "ACTIVE",
            expires_at: license.date_fin,
            features: {
                allow_backup: license.option_sauvegarde,
                allow_backoffice: license.option_backoffice,
                allow_realtime_x: license.option_synchro_x_realtime
            }
        });

    } catch (error) {
        console.error("Erreur d'extraction de licence Sync Engine :", error);
        return res.status(500).json({ error: "Erreur lors de la génération du payload de licence." });
    }
};
