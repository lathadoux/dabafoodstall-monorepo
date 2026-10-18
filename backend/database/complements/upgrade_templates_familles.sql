-- path: backend/upgrade_templates_familles.sql

-- 1. Table d'association : Quelles familles (onglets) composent quel gabarit ?
CREATE TABLE IF NOT EXISTS template_familles (
    id_template INT REFERENCES catalog_templates(id_template) ON DELETE CASCADE,
    id_famille INT REFERENCES familles(id_famille) ON DELETE CASCADE,
    PRIMARY KEY (id_template, id_famille)
);

-- 📊 INJECTION ET RÉPARTITION DES ONGLETS PAR PROFIL MÉTIER (09 Octobre 2026)

-- A. PEUPLEMENT POUR LE TEMPLATE 1 : Kiosque Garba 🐟
-- Il a besoin des onglets Plats (Garba), Accompagnements (Attiéké), Épicerie, Énergie...
INSERT INTO template_familles (id_template, id_famille) VALUES 
(1, 1), -- Garba 🐟
(1, 2), -- Attiéké 🌾
(1, 3), -- Condiments 🌶️
(1, 4), -- Boissons 🥤
(1, 5), -- Général 🏢
(1, 6), -- Épicerie 🧅
(1, 7)  -- Énergie ⚡
ON CONFLICT DO NOTHING;

-- B. PEUPLEMENT POUR LE TEMPLATE 2 : Stand Jus & Boissons 🥤
-- Ce profil n'affiche QUE les onglets de boissons et les dépenses d'achats spécifiques
INSERT INTO template_familles (id_template, id_famille) VALUES 
(2, 4), -- Boissons 🥤 (Le même onglet partagé que le Garba)
(2, 5), -- Général 🏢 (Pour les charges fixes du stand)
(2, 9)  -- Désaltérants 🧪 (Onglet d'achats de matières premières : sucre, gingembre, hibiscus...)
ON CONFLICT DO NOTHING;
