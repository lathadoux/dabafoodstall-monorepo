CREATE TABLE IF NOT EXISTS web_provisioning_queue (
    id_provisioning SERIAL PRIMARY KEY,
    web_fingerprint VARCHAR(64) NOT NULL UNIQUE,       -- Empreinte du navigateur Web
    tenant_id INT NOT NULL REFERENCES tenants(id_tenant) ON DELETE CASCADE,
    id_pos INT NOT NULL REFERENCES points_de_vente(id_pos) ON DELETE CASCADE,
    id_user_manager INT NOT NULL REFERENCES users(id_user) ON DELETE CASCADE,
    type_pos VARCHAR(30) NOT NULL,                    -- 'garba_stall', 'alloco_stall', etc.
    date_creation TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    statut_liaison VARCHAR(20) DEFAULT 'en_attente' CHECK (statut_liaison IN ('en_attente', 'scelle_termine'))
);

-- Indexation chirurgicale pour le premier boot du mobile
CREATE INDEX IF NOT EXISTS idx_web_prov_hash ON web_provisioning_queue(web_fingerprint);
