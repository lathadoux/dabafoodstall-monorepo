-- ===========================================================================
-- 🏢 AXE 1 : COMPOSANTS CŒUR MULTI-TENANT & INFRASTRUCTURE SAAS
-- ===========================================================================

CREATE TABLE IF NOT EXISTS tenants (
    id_tenant SERIAL PRIMARY KEY,
    nom_business VARCHAR(100) NOT NULL,
    date_inscription TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS points_de_vente (
    id_pos SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    nom_pos VARCHAR(100) NOT NULL,
    type_pos VARCHAR(30) NOT NULL CHECK (type_pos IN ('garba_stall', 'alloco_stall', 'general')),
    UNIQUE(id_tenant, nom_pos)
);

CREATE TABLE IF NOT EXISTS public.plans_abonnement (
    plan_id SERIAL PRIMARY KEY,
    nom_plan VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    option_sauvegarde BOOLEAN DEFAULT FALSE,
    option_backoffice BOOLEAN DEFAULT FALSE,
    option_synchro_x_realtime BOOLEAN DEFAULT FALSE,
    tarif_mensuel NUMERIC(10, 2) NOT NULL,
    devise VARCHAR(3) DEFAULT 'XOF',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS abonnements (
    id_abonnement SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    pos_id INT NOT NULL REFERENCES points_de_vente(id_pos) ON DELETE CASCADE,
    plan_id INT REFERENCES public.plans_abonnement(plan_id),
    web_fingerprint VARCHAR(64) NOT NULL UNIQUE,       
    device_fingerprint VARCHAR(64) UNIQUE,             
    pos_raison_sociale VARCHAR(100) NOT NULL,
    term_phone_number VARCHAR(20) NOT NULL,
    date_demande TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    date_activation_cloud TIMESTAMP WITH TIME ZONE,    
    date_expiration_cloud TIMESTAMP WITH TIME ZONE NOT NULL, 
    statut_abonnement VARCHAR(20) DEFAULT 'en_attente' CHECK (statut_abonnement IN ('en_attente', 'actif', 'bride')),
    client_email VARCHAR(100),
    whatsapp_number VARCHAR(20),
    commune VARCHAR(50),
    quartier VARCHAR(50),
    adresse_geographique TEXT,
    gps_coordinates VARCHAR(50),
    client_civilite VARCHAR(10) CHECK (client_civilite IN ('M.', 'Mme', 'Mlle')),
    client_nom VARCHAR(100),
    client_prenom VARCHAR(100),
    date_naissance DATE,
    type_pos VARCHAR(40) DEFAULT 'general',
    code_activation_court VARCHAR(15) UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_abonnements_code_court ON abonnements(code_activation_court);
CREATE INDEX IF NOT EXISTS idx_abonnement_dfp ON abonnements(device_fingerprint);

CREATE TABLE IF NOT EXISTS public.terminaux (
    id_terminal SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_pos INTEGER NOT NULL REFERENCES points_de_vente(id_pos) ON DELETE CASCADE,
    imei_appareil VARCHAR(64) UNIQUE NOT NULL, 
    nom_terminal VARCHAR(50) NOT NULL,
    device_fingerprint VARCHAR(64) UNIQUE,
    date_expiration TIMESTAMP WITH TIME ZONE,
    date_activation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS paiements_licences (
    id_paiement SERIAL PRIMARY KEY,
    id_abonnement INT NOT NULL REFERENCES abonnements(id_abonnement) ON DELETE CASCADE,
    reference_operateur VARCHAR(100) UNIQUE NOT NULL, 
    operateur_utilise VARCHAR(20) NOT NULL CHECK (operateur_utilise IN ('WAVE', 'ORANGE', 'MTN', 'MOOV')),
    montant_verse NUMERIC(10,2) NOT NULL,
    mois_prolongation INT NOT NULL DEFAULT 1,
    date_paiement TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ===========================================================================
-- ⬇️ AXE 2 : DESCENTE DIFFÉRENTIELLE (DELTA DOWNLOAD)
-- ===========================================================================

CREATE TABLE IF NOT EXISTS familles (
    id_famille SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    nom_famille VARCHAR(100) NOT NULL,
    type_famille VARCHAR(20) NOT NULL CHECK (type_famille IN ('vente', 'achat')),
    type_pos VARCHAR(30) NOT NULL DEFAULT 'general',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    UNIQUE(id_tenant, nom_famille)
);

CREATE TABLE IF NOT EXISTS articles (
    id_article SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_famille INTEGER NOT NULL REFERENCES familles(id_famille) ON DELETE RESTRICT,
    nom_article VARCHAR(100) NOT NULL,
    type_article VARCHAR(20) NOT NULL CHECK (type_article IN ('vente', 'achat')),
    prix_unitaire NUMERIC(12, 2) CHECK (prix_unitaire >= 0),
    unite_mesure VARCHAR(20) NOT NULL DEFAULT 'pcs',
    type_pos VARCHAR(30) NOT NULL DEFAULT 'general',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    UNIQUE(id_tenant, nom_article),
    CONSTRAINT check_prix_vente_obligatoire CHECK (
        (type_article = 'vente' AND prix_unitaire IS NOT NULL) OR (type_article = 'achat')
    )
);

CREATE TABLE IF NOT EXISTS users (
    id_user SERIAL PRIMARY KEY,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    nom_user VARCHAR(100) NOT NULL,
    role_user VARCHAR(20) NOT NULL CHECK(role_user IN ('super_admin', 'admin', 'manager', 'vendor', 'commercial')),
    password_user VARCHAR(255) NOT NULL,
    pin_user VARCHAR(10) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
);

-- ===========================================================================
-- ⬆️ AXE 3 : REMONTÉE ET TRANSACTIONNEL COMPTOIR (UPLOAD & COMPTABILITÉ)
-- ===========================================================================

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

CREATE TABLE IF NOT EXISTS orders (
    id_cde SERIAL PRIMARY KEY,
    id_session INTEGER NOT NULL REFERENCES cash_sessions(id_session) ON DELETE RESTRICT,
    id_tenant INTEGER NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_user INTEGER NOT NULL REFERENCES users(id_user) ON DELETE RESTRICT,
    date_heure_cde TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    statut_commande VARCHAR(20) DEFAULT 'actif' CHECK(statut_commande IN ('actif', 'en_attente', 'paye')),
    statut_sync INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS order_items (
    id_cde INTEGER NOT NULL REFERENCES orders(id_cde) ON DELETE CASCADE,
    id_article INTEGER NOT NULL REFERENCES articles(id_article) ON DELETE RESTRICT,
    qte_vendue INTEGER NOT NULL CHECK(qte_vendue > 0),
    prix_facture NUMERIC(12, 2) NOT NULL,
    PRIMARY KEY (id_cde, id_article)
);

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

CREATE TABLE IF NOT EXISTS cloud_sync_sessions_z (
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

CREATE TABLE IF NOT EXISTS public.realtime_rapport_x (
    tenant_id VARCHAR(50) PRIMARY KEY,
    ca_provisoire NUMERIC(10, 2) NOT NULL,
    nb_transactions INT NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===========================================================================
-- ⚙️ AUTOMATED TRIGGERS : CALCUL AUTOMATIQUE DU SOLDE DE COMPTOIR EN DIRECT
-- ===========================================================================
CREATE OR REPLACE FUNCTION fn_sync_update_cash_balance()
RETURNS TRIGGER AS $$
BEGIN
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