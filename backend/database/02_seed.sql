-- ===========================================================================
-- 🌱 PARTIE 2 : INJECTION DES JEUX DE DONNÉES ET SEEDERS D'USINE
-- ===========================================================================

-- 1. Insertion des entreprises locataires
INSERT INTO tenants (id_tenant, nom_business) VALUES 
(1, 'Daba Food Stall LLC'),
(2, 'Enseigne Centrale Côte d''Ivoire')
ON CONFLICT (id_tenant) DO NOTHING;
-- 🔑 RECALAGE TECHNIQUE DE L'AUTO-INCRÉMENT (Résout le conflit d'enrôlement CRM)
-- Aligne la séquence sur le maximum existant (10), le prochain enrôlement prendra automatiquement l'ID 11

-- 3. Insertion des points de vente assignés aux locataires (Épuré de id_template)
INSERT INTO points_de_vente (id_pos, id_tenant, nom_pos, type_pos) VALUES 
(1, 1, 'Stand de Garba de la Cité Real-Time', 'garba_stall'),
(2, 2, 'Étal Riviera 2', 'garba_stall')
ON CONFLICT (id_pos) DO NOTHING;
-- 🔑 CORRECTIF SYNC ENGINE V2 : Recalage immédiat de la séquence SERIAL de points_de_vente
-- Force le compteur à s'aligner sur la valeur maximale (2). Le prochain insert prendra l'ID 3.

-- 4. Enrôlement du matériel physique de test (Émulateur)
INSERT INTO terminaux (id_terminal, id_tenant, id_pos, imei_appareil, nom_terminal) VALUES 
(1, 2, 2, 'de498e5e70c3c4c22ca45f197eb686d844449af574bbe4b13eb86f14f38fb152', 'Caisse Émulateur Android x64')
ON CONFLICT (imei_appareil) DO UPDATE SET id_pos = EXCLUDED.id_pos;

-- 6. Profils utilisateurs avec droits initiaux
-- Nettoyage des anciennes graines pour éviter les conflits d'index séquentiels
DELETE FROM users WHERE id_user IN (3, 4, 5);

-- 🏢 INJECTION DU PERSONNEL DU GRAND LIVRE (ALIGNE SUR 2 NIVEAUX D'ADMIN)
INSERT INTO users (id_user, id_tenant, nom_user, role_user, password_user, pin_user) VALUES 
(1, 2, 'Koffi Alexis', 'manager', 'pass', '2026'),
(2, 2, 'Moussa Diop', 'vendor', 'pass', '1234'),
(3, 2, 'Super Admin pos', 'admin', 'admin', '0000'), -- 🔑 Gérant de l'étal local

(4, 1, 'Super Admin Cloud', 'super_admin', 'admin', '9999'), -- 🔑 Propriétaire SaaS
(5, 1, 'Awa Touré', 'commercial', 'pass', '7788') -- 🔑 Force de vente
ON CONFLICT (id_user) DO NOTHING;

-- 7. Catalogue des Familles d'Articles (Onglets)
INSERT INTO familles (id_famille, id_tenant, nom_famille, type_famille, type_pos) VALUES 
(1, 1, 'Garba 🐟', 'vente', 'garba_stall'),
(2, 1, 'Attiéké 🌾', 'vente', 'garba_stall'),
(3, 1, 'Condiments 🌶️', 'vente', 'garba_stall'),
(4, 1, 'Boissons 🥤', 'vente', 'garba_stall'),
(5, 1, 'Général 🏢', 'achat', 'garba_stall'),
(6, 1, 'Épicerie 🧅', 'achat', 'garba_stall'),
(7, 1, 'Énergie ⚡', 'achat', 'garba_stall'),
(8, 1, 'Ustensiles 🍳', 'achat', 'garba_stall'),
(9, 1, 'Désaltérants 🥤', 'achat', 'garba_stall'),
(10, 1, 'Mouvements Coffre 🪙', 'vente', 'general')
ON CONFLICT (id_famille) DO NOTHING;

-- 8. Catalogue des 33 Articles de base du Grand Livre
INSERT INTO articles (id_article, id_tenant, id_famille, nom_article, type_article, prix_unitaire, unite_mesure, type_pos) VALUES
(1, 1, 1, 'garba_150', 'vente', 150.00, 'pcs', 'garba_stall'),
(2, 1, 1, 'garba_200', 'vente', 200.00, 'pcs', 'garba_stall'),
(3, 1, 1, 'garba_250', 'vente', 250.00, 'pcs', 'garba_stall'),
(4, 1, 1, 'garba_300', 'vente', 300.00, 'pcs', 'garba_stall'),
(5, 1, 1, 'garba_400', 'vente', 400.00, 'pcs', 'garba_stall'),
(6, 1, 1, 'garba_500', 'vente', 500.00, 'pcs', 'garba_stall'),
(7, 1, 2, 'Attiéké_100', 'vente', 100.00, 'pcs', 'garba_stall'),
(8, 1, 2, 'Attiéké_50', 'vente', 50.00, 'pcs', 'garba_stall'),
(9, 1, 2, 'Attiéké_200', 'vente', 200.00, 'pcs', 'garba_stall'),
(10, 1, 2, 'Attiéké_300', 'vente', 300.00, 'pcs', 'garba_stall'),
(11, 1, 3, 'tomate_50', 'vente', 50.00, 'pcs', 'garba_stall'),
(12, 1, 3, 'tomate_100', 'vente', 100.00, 'pcs', 'garba_stall'),
(13, 1, 3, 'oignon_50', 'vente', 50.00, 'pcs', 'garba_stall'),
(14, 1, 3, 'oignon_100', 'vente', 100.00, 'pcs', 'garba_stall'),
(15, 1, 3, 'mayo_50', 'vente', 50.00, 'pcs', 'garba_stall'),
(16, 1, 3, 'Œuf Dur', 'vente', 100.00, 'pcs', 'garba_stall'),
(17, 1, 3, 'Cube Maggi', 'vente', 50.00, 'pcs', 'garba_stall'),
(18, 1, 4, 'eau-pack_50', 'vente', 50.00, 'pcs', 'garba_stall'),
(19, 1, 5, 'Poisson au montant', 'achat', NULL, 'kg', 'garba_stall'),
(20, 1, 5, 'Attiéké au montant', 'achat', NULL, 'sac', 'garba_stall'),
(21, 1, 6, 'huile_bid_6l', 'achat', 5000.00, 'pcs', 'garba_stall'),
(22, 1, 6, 'tomate_vrac', 'achat', NULL, 'lot', 'garba_stall'),
(23, 1, 6, 'oignon_vrac', 'achat', NULL, 'lot', 'garba_stall'),
(24, 1, 6, 'piment_vrac', 'achat', NULL, 'lot', 'garba_stall'),
(25, 1, 6, 'cube_plaq', 'achat', 600.00, 'pcs', 'garba_stall'),
(26, 1, 6, 'mayo_chap', 'achat', 1000.00, 'pcs', 'garba_stall'),
(27, 1, 7, 'gaz_recharge', 'achat', 2500.00, 'pcs', 'garba_stall'),
(28, 1, 7, 'gaz_bonbonne', 'achat', 1500.00, 'pcs', 'garba_stall'),
(29, 1, 8, 'poele', 'achat', 5000.00, 'pcs', 'garba_stall'),
(30, 1, 8, 'ecumoire', 'achat', 2000.00, 'pcs', 'garba_stall'),
(31, 1, 8, 'assiettes', 'achat', 100.00, 'pcs', 'garba_stall'),
(32, 1, 8, 'gobelets', 'achat', 200.00, 'pcs', 'garba_stall'),
(33, 1, 9, 'sac_eau', 'achat', 600.00, 'sac', 'garba_stall')
ON CONFLICT (id_article) DO NOTHING;

-- 9. Articles de gouvernance des mouvements de flux de caisse
INSERT INTO articles (id_article, id_tenant, id_famille, nom_article, type_article, prix_unitaire, unite_mesure) VALUES
(901, 1, 10, 'Appro Caisse (+)', 'vente', 1.00, 'F'),
(902, 1, 10, 'Versement  (-)', 'achat', 1.00, 'F')
ON CONFLICT (id_article) DO NOTHING;

-- ===========================================================================
-- 🔒 SÉCURISATION ARCHITECTURALE : RECALAGE GLOBAL DES SÉQUENCES (ANTI-COLLISION V2)
-- Force toutes les séquences SERIAL à démarrer APRÈS le maximum injecté par le seeder
-- ===========================================================================

-- 1. Recalage de la table Tenants (Locataires)
SELECT setval(pg_get_serial_sequence('public.tenants', 'id_tenant'), COALESCE(MAX(id_tenant), 1)) FROM public.tenants;

-- 2. Recalage de la table Points de Vente (POS)
SELECT setval(pg_get_serial_sequence('public.points_de_vente', 'id_pos'), COALESCE(MAX(id_pos), 1)) FROM public.points_de_vente;

-- 3. Recalage de la table Terminaux (Matériel)
SELECT setval(pg_get_serial_sequence('public.terminaux', 'id_terminal'), COALESCE(MAX(id_terminal), 1)) FROM public.terminaux;

-- 4. Recalage de la table Familles (Delta Download)
SELECT setval(pg_get_serial_sequence('public.familles', 'id_famille'), COALESCE(MAX(id_famille), 1)) FROM public.familles;

-- 5. Recalage de la table Articles (Delta Download)
SELECT setval(pg_get_serial_sequence('public.articles', 'id_article'), COALESCE(MAX(id_article), 1)) FROM public.articles;

-- 6. Recalage de la table Users (Grand Livre RH)
SELECT setval(pg_get_serial_sequence('public.users', 'id_user'), COALESCE(MAX(id_user), 1)) FROM public.users;

-- ===========================================================================
-- 🏢 INFRASTRUCTURE SAAS : GRILLE COMMERCIALE SCELLÉE
-- ===========================================================================
INSERT INTO public.plans_abonnement (nom_plan, description, option_sauvegarde, option_backoffice, option_synchro_x_realtime, tarif_mensuel, devise)
VALUES 
('Sauvegarde standard', 'Accès à la remontée des journaux et bilan de clôture', TRUE, FALSE, FALSE, 5000.00, 'XOF'),
('BackOffice Intégral', 'Accès complet au catalogue distant, utilisateurs et PIN Admin', TRUE, TRUE, FALSE, 10000.00, 'XOF'),
('Souverain Full-Sync', 'Toutes les options incluses + Suivi du Rapport X en temps réel', TRUE, TRUE, TRUE, 15000.00, 'XOF')
ON CONFLICT (nom_plan) DO NOTHING;