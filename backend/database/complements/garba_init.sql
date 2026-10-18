-- ===========================================================================
-- 🏢 SCHÉMA MULTI-TENANT CORRIGÉ ET SEEDÉ - DABAFOODSTALL
-- ===========================================================================

-- 1. TABLE DES LOCATAIRES
CREATE TABLE IF NOT EXISTS tenants (
    id_tenant SERIAL PRIMARY KEY,
    nom_business VARCHAR(100) NOT NULL,
    date_inscription TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. TABLE DES POINTS DE VENTE (POS)
CREATE TABLE IF NOT EXISTS points_de_vente (
    id_pos SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    nom_pos VARCHAR(100) NOT NULL,
    type_pos VARCHAR(30) NOT NULL CHECK (type_pos IN ('garba_stall', 'alloco_stall', 'general')),
    UNIQUE(id_tenant, nom_pos)
);

-- 3. TABLE DES CONFIGURATIONS DE SÉCURITÉ LOCALES
CREATE TABLE IF NOT EXISTS pos_params (
    id_param SERIAL PRIMARY KEY,
    id_tenant INT NOT NULL,
    nom_pos VARCHAR(100) NOT NULL,
    telephone_pos VARCHAR(20) DEFAULT '+225 00 00 00 00',
    devise VARCHAR(5) DEFAULT 'F',
    adresse_pos TEXT DEFAULT 'Abidjan, Côte d''Ivoire',
    version_schema VARCHAR(10) DEFAULT 'V1.0'
);

-- 4. TABLE DE PRÉ-ENRÔLEMENT WEB DES APPAREILS
CREATE TABLE IF NOT EXISTS devices_provisioning (
    id_device SERIAL PRIMARY KEY,
    imei_terminal VARCHAR(64) UNIQUE NOT NULL,
    id_tenant INT NOT NULL,
    id_pos INT NOT NULL,
    nom_pos VARCHAR(100) NOT NULL,
    telephone_pos VARCHAR(20),
    adresse_pos TEXT,
    statut_activation BOOLEAN DEFAULT TRUE,
    date_enrolement TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. TABLE DES FAMILLES D'ARTICLES
CREATE TABLE IF NOT EXISTS familles (
    id_famille SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    nom_famille VARCHAR(100) NOT NULL,
    type_famille VARCHAR(20) NOT NULL CHECK (type_famille IN ('vente', 'achat')),
    type_pos VARCHAR(30) NOT NULL DEFAULT 'general', 
    UNIQUE(id_tenant, nom_famille)
);

-- 6. TABLE DES ARTICLES
CREATE TABLE IF NOT EXISTS articles (
    id_article SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_famille INTEGER NOT NULL REFERENCES familles(id_famille) ON DELETE RESTRICT,
    nom_article VARCHAR(100) NOT NULL,
    type_article VARCHAR(20) NOT NULL CHECK (type_article IN ('vente', 'achat')),
    prix_unitaire NUMERIC(12, 2) CHECK (prix_unitaire >= 0),
    unite_mesure VARCHAR(20) NOT NULL DEFAULT 'pcs',
    type_pos VARCHAR(30) NOT NULL DEFAULT 'general', 
    UNIQUE(id_tenant, nom_article),
    CONSTRAINT check_prix_vente_obligatoire CHECK (
        (type_article = 'vente' AND prix_unitaire IS NOT NULL) OR (type_article = 'achat')
    )
);

-- 7. TABLE DES TERMINAUX AUTORISÉS (SÉCURITÉ COUCHE MATÉRIELLE)
CREATE TABLE IF NOT EXISTS terminaux (
    id_terminal SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_pos INTEGER NOT NULL REFERENCES points_de_vente(id_pos) ON DELETE CASCADE,
    imei_appareil VARCHAR(64) UNIQUE NOT NULL, -- Taille augmentée pour supporter les hashs SHA-256
    nom_terminal VARCHAR(50) NOT NULL,
    date_activation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. TABLE DES UTILISATEURS (RBAC / DOUBLE AUTHENTIFICATION)
CREATE TABLE IF NOT EXISTS users (
    id_user SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    nom_user VARCHAR(100) NOT NULL,
    role_user VARCHAR(20) NOT NULL CHECK(role_user IN ('admin', 'manager', 'vendor')),
    password_user VARCHAR(255) NOT NULL,
    pin_user VARCHAR(10) NOT NULL
);

-- 9. TABLE DES SESSIONS DE CAISSE
CREATE TABLE IF NOT EXISTS cash_sessions (
    id_session SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_user INTEGER NOT NULL REFERENCES users(id_user) ON DELETE RESTRICT,
    date_heure_ouv TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    date_heure_clot TIMESTAMP WITH TIME ZONE,
    montant_init NUMERIC(12, 2) NOT NULL CHECK(montant_init >= 0),
    montant_theo NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    montant_reel NUMERIC(12, 2),
    statut_sync INTEGER NOT NULL DEFAULT 0 CHECK(statut_sync IN (0, 1))
);

-- 10. TABLE DES COMMANDES
CREATE TABLE IF NOT EXISTS orders (
    id_cde SERIAL PRIMARY KEY,
    id_session INTEGER NOT NULL REFERENCES cash_sessions(id_session) ON DELETE RESTRICT,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_user INTEGER NOT NULL REFERENCES users(id_user) ON DELETE RESTRICT,
    date_heure_cde TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    statut_commande VARCHAR(20) DEFAULT 'actif' CHECK(statut_commande IN ('actif', 'en_attente', 'paye')),
    statut_sync INT DEFAULT 0
);

-- 11. TABLE DES LIGNES DE COMMANDES (ORDER ITEMS)
CREATE TABLE IF NOT EXISTS order_items (
    id_cde INTEGER NOT NULL REFERENCES orders(id_cde) ON DELETE CASCADE,
    id_article INTEGER NOT NULL REFERENCES articles(id_article) ON DELETE RESTRICT,
    qte_vendue INTEGER NOT NULL CHECK(qte_vendue > 0),
    prix_facture NUMERIC(12, 2) NOT NULL,
    PRIMARY KEY (id_cde, id_article)
);

-- 12. TABLE DES TRANSACTIONS FINANCIÈRES
CREATE TABLE IF NOT EXISTS financial_transactions (
    id_trans SERIAL PRIMARY KEY,
    id_session INTEGER NOT NULL REFERENCES cash_sessions(id_session) ON DELETE RESTRICT,
    id_cde INTEGER REFERENCES orders(id_cde) ON DELETE SET NULL,
    id_article_achat INTEGER REFERENCES articles(id_article) ON DELETE SET NULL,
    type_trans VARCHAR(30) NOT NULL CHECK(type_trans IN ('ouverture', 'encaissement_vente', 'achat_direct', 'versement')),
    montant_trans NUMERIC(12, 2) NOT NULL CHECK(montant_trans >= 0),
    sens_flux VARCHAR(10) NOT NULL CHECK(sens_flux IN ('DEBIT', 'CREDIT')),
    mode_reglement VARCHAR(20) NOT NULL CHECK(mode_reglement IN ('especes', 'orange_money', 'wave', 'mtn_money')),
    qte_achat_historique NUMERIC(10, 2) DEFAULT 0.00,
    date_heure_trans TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    statut_sync INTEGER NOT NULL DEFAULT 0
);

-- 13. TABLE DES RAPPORTS Z SCELLÉS EN LOCAL (SQLITE)
CREATE TABLE IF NOT EXISTS rapports_z (
    id_rapport_z SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_session INTEGER UNIQUE NOT NULL REFERENCES cash_sessions(id_session) ON DELETE RESTRICT,
    date_generation TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    total_ventes NUMERIC(12, 2) NOT NULL,
    total_achats NUMERIC(12, 2) NOT NULL,
    solde_especes NUMERIC(12, 2) NOT NULL,
    solde_mobile_money NUMERIC(12, 2) NOT NULL,
    ecart_caisse NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    signature_hash VARCHAR(64) NOT NULL,
    statut_sync INTEGER NOT NULL DEFAULT 0
);

-- 14. 🔑 LE COFFRE-FORT CENTRALISÉ JSONB POUR LES SESSIONS DE FIN DE JOURNÉE Z
DROP TABLE IF EXISTS cloud_sync_sessions_z CASCADE;
CREATE TABLE cloud_sync_sessions_z (
    id_sync_cloud SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL,
    id_pos INT NOT NULL,
    device_fingerprint VARCHAR(64) NOT NULL,
    id_session_local INT NOT NULL,
    date_cloture_locale TIMESTAMP NOT NULL,
    date_reception_cloud TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, 
    payload_complet_jsonb JSONB NOT NULL,
    CONSTRAINT unique_terminal_session UNIQUE (tenant_id, id_pos, device_fingerprint, id_session_local)
);

CREATE INDEX IF NOT EXISTS idx_jsonb_payload_global ON cloud_sync_sessions_z USING gin (payload_complet_jsonb);

-- ===========================================================================
-- 🌱 INJECTION DE L'ÉCOSYSTÈME DE PRODUCTION IDEMPOTENT (SEEDERS CLOUD)
-- ===========================================================================

-- Création étanche des deux environnements de test constatés dans les payloads
INSERT INTO tenants (id_tenant, nom_business) VALUES 
(1, 'Daba Food Stall LLC'),
(10, 'Enseigne Centrale Côte d''Ivoire') -- 🔑 Fix : Ajout du tenant maître de test
ON CONFLICT (id_tenant) DO NOTHING;

INSERT INTO points_de_vente (id_pos, id_tenant, nom_pos, type_pos) VALUES 
(1, 1, 'Stand de Garba de la Cité Real-Time', 'garba_stall'),
(2, 10, 'Étal Riviera 2', 'garba_stall') -- 🔑 Fix : Autorise le POS envoyé par Flutter
ON CONFLICT (id_pos) DO NOTHING;

-- Enrôlement matériel définitif de votre Émulateur Android
INSERT INTO terminaux (id_terminal, id_tenant, id_pos, imei_appareil, nom_terminal) VALUES 
(1, 10, 2, 'de498e5e70c3c4c22ca45f197eb686d844449af574bbe4b13eb86f14f38fb152', 'Caisse Émulateur Android x64')
ON CONFLICT (imei_appareil) DO UPDATE SET id_pos = EXCLUDED.id_pos;

INSERT INTO pos_params (id_tenant, nom_pos, telephone_pos, devise, adresse_pos, version_schema)
VALUES (1, 'Étal Pilote Abidjan', '+225 07 01 02 03', 'F', 'Zone 4, Abidjan', 'V1.0')
ON CONFLICT DO NOTHING;

-- Injection du personnel RH avec mots de passe d'usine synchronisés sur 'pass'
INSERT INTO users (id_user, id_tenant, nom_user, role_user, password_user, pin_user) VALUES 
(1, 10, 'Koffi Alexis', 'manager', 'pass', '2026'), -- 🔑 Alignement sur le mot de passe réel
(2, 10, 'Moussa Diop', 'vendor', 'pass', '1234'),
(3, 1, 'Super Admin Daba', 'admin', 'admin', '0000') 
ON CONFLICT (id_user) DO NOTHING;

-- Injection des 10 familles d'articles
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

-- Injection des 33 articles du Grand Livre
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
INSERT INTO articles (id_article, id_tenant, id_famille, nom_article, type_article, prix_unitaire, unite_mesure) VALUES
(901, 1, 10, 'Appro Caisse (+)', 'vente', 1.00, 'F'),
(902, 1, 10, 'Versement  (-)', 'achat', 1.00, 'F')
ON CONFLICT (id_article) DO NOTHING;
SELECT setval(pg_get_serial_sequence('articles', 'id_article'), COALESCE(MAX(id_article), 1)) FROM articles;
-- ===========================================================================
-- AUTOMATED TRIGGERS : GESTION DES FLUX FINANCIERS DE COMPTOIR
-- ===========================================================================
CREATE OR REPLACE FUNCTION fn_sync_update_cash_balance()
RETURNS TRIGGER AS $$
BEGIN
-- 🔑 CORRECTION LOGIQUE COMPTABLE :
-- Un CREDIT ajoute du cash au solde théorique (Encaissement vente / Appro).
-- Un DEBIT retire du cash (Achat direct d'ingrédients / Versement patron).
UPDATE cash_sessions
SET montant_theo = montant_theo + CASE
WHEN NEW.sens_flux = 'CREDIT' THEN NEW.montant_trans
WHEN NEW.sens_flux = 'DEBIT'  THEN -NEW.montant_trans
ELSE 0.00
END
WHERE id_session = NEW.id_session;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE TRIGGER trg_server_update_cash_balance
AFTER INSERT ON financial_transactions
FOR EACH ROW EXECUTE FUNCTION fn_sync_update_cash_balance();

---