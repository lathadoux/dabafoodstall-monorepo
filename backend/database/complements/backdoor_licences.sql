-- path: backend/database/backdoor_licences.sql

CREATE TABLE IF NOT EXISTS developer_promo_tokens (
    id_token SERIAL PRIMARY KEY,
    token_code VARCHAR(32) UNIQUE NOT NULL,          -- Le code secret à saisir (ex: GENZO_DEMO_2026_X)
    jours_gratuits INT NOT NULL DEFAULT 7,           -- Durée de la prolongation (3, 7 ou 30 jours)
    statut_token VARCHAR(20) DEFAULT 'actif' CHECK (statut_token IN ('actif', 'utilise', 'expire')),
    attribue_a VARCHAR(100) NOT NULL,                -- Nom du commercial ou 'Dev-Local'
    date_utilisation TIMESTAMP WITH TIME ZONE
);

-- Indexation d'accès rapide pour la validation flash
CREATE INDEX IF NOT EXISTS idx_token_code ON developer_promo_tokens(token_code);
