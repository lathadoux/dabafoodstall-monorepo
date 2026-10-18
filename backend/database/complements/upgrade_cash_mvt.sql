-- path: backend/upgrade_cash_mvt.sql
BEGIN;

-- 1. Insertion de la famille de gouvernance des flux de coffre
INSERT INTO familles (id_famille, id_tenant, nom_famille, type_famille) 
VALUES (10, 1, 'Mouvements Coffre 🪙', 'vente')
ON CONFLICT (id_famille) DO NOTHING;

-- 2. Insertion de l'article d'approvisionnement (Entrée)
INSERT INTO articles (id_article, id_tenant, id_famille, nom_article, type_article, prix_unitaire, unite_mesure)
VALUES (901, 1, 10, 'Appro Caisse (+)', 'vente', 1.00, 'F')
ON CONFLICT (id_article) DO NOTHING;

-- 3. Insertion de l'article de versement (Sortie)
INSERT INTO articles (id_article, id_tenant, id_famille, nom_article, type_article, prix_unitaire, unite_mesure)
VALUES (902, 1, 10, 'Versement  (-)', 'achat', 1.00, 'F')
ON CONFLICT (id_article) DO NOTHING;

COMMIT;
