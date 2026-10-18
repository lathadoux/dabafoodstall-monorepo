-- path: backend/upgrade_templates.sql

-- A. Création de la table des modèles/gabarits de catalogues
CREATE TABLE IF NOT EXISTS catalog_templates (
    id_template SERIAL PRIMARY KEY,
    id_tenant INT NOT NULL,
    nom_template VARCHAR(100) NOT NULL, -- 'Gabarit Kiosque Garba', 'Gabarit Stand Boissons', 'Gabarit Alloco'
    description TEXT,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- B. Table d'association : Quels articles composent quel gabarit ?
CREATE TABLE IF NOT EXISTS template_articles (
    id_template INT REFERENCES catalog_templates(id_template) ON DELETE CASCADE,
    id_article INT REFERENCES articles(id_article) ON DELETE CASCADE,
    PRIMARY KEY (id_template, id_article)
);

-- C. Évolution de la table des Points de Vente pour y associer un gabarit spécifique
ALTER TABLE points_de_vente ADD COLUMN IF NOT EXISTS id_template INT REFERENCES catalog_templates(id_template);


-- 📊 INJECTION DES GABARITS DE TEST (09 Octobre 2026)
-- 1. Création des Templates pour le Tenant 1
INSERT INTO catalog_templates (id_template, id_tenant, nom_template, description) VALUES 
(1, 1, 'Gabarit Kiosque Garba 🐟', 'Contient les déclinaisons de Garba, Attiéké et condiments associés'),
(2, 1, 'Gabarit Stand Jus & Boissons 🥤', 'Dédié exclusivement aux rafraîchissements, jus locaux (Bissap, Gnamankou) et sodas')
ON CONFLICT DO NOTHING;

-- 2. Association des articles existants au Template 1 (Garba)
-- Supposons que vos articles 1, 2, 3 sont vos portions de Garba
INSERT INTO template_articles (id_template, id_article) VALUES 
(1, 1), (1, 2), (1, 3)
ON CONFLICT DO NOTHING;

-- 3. Affectation du Gabarit 1 au Point de Vente Pilote (id_pos = 1)
UPDATE points_de_vente SET id_template = 1 WHERE id_pos = 1;
