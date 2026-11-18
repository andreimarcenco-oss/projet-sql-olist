-- ============================================================
-- Projet Olist : analyse clients d'un site e-commerce
-- 01 - Découverte des données
-- Base : olist.db (SQLite), source : Kaggle "Brazilian E-Commerce Public Dataset by Olist"
-- ============================================================


-- ------------------------------------------------------------
-- 1. Les identifiants clients : customer_id vs customer_unique_id
-- ------------------------------------------------------------

-- Nombre total de commandes
SELECT COUNT(*) AS nb_commandes
FROM orders;
-- Résultat : 99 441 commandes


-- Nombre de customer_id et de customer_unique_id distincts
SELECT
    COUNT(DISTINCT customer_id)        AS nb_customer_id,
    COUNT(DISTINCT customer_unique_id) AS nb_clients_reels
FROM customers;
-- Résultat : 99 441 customer_id / 96 096 customer_unique_id

-- Conclusion :
-- - Autant de customer_id que de commandes : un customer_id est créé à chaque commande.
-- - customer_unique_id identifie la personne réelle : Olist compte 96 096 clients.
-- - 3 345 commandes "en plus" (99 441 - 96 096) : la part de clients qui reviennent
--   est donc faible. Le nombre exact de clients fidèles est calculé à l'étape 03.
-- => Point d'attention : toute analyse de fidélité doit utiliser customer_unique_id.


-- ------------------------------------------------------------
-- 2. order_items : une ligne = un article dans une commande
-- ------------------------------------------------------------

SELECT
    COUNT(*)                 AS nb_lignes,
    COUNT(DISTINCT order_id) AS nb_commandes_avec_articles
FROM order_items;
-- Résultat : 112 650 lignes pour 98 666 commandes distinctes
-- Une commande de plusieurs produits a plusieurs lignes (order_item_id = 1, 2, 3...).
-- 99 441 - 98 666 = 775 commandes n'ont aucun article (voir statuts ci-dessous).


-- ------------------------------------------------------------
-- 3. Statuts de commande
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS nb_commandes
FROM orders
GROUP BY order_status
ORDER BY nb_commandes DESC;
-- Résultat : delivered 96 478 / shipped 1 107 / canceled 625 / unavailable 609
--            invoiced 314 / processing 301 / created 5 / approved 2

-- Choix retenu pour tout le projet :
-- on garde les commandes 'delivered' et 'shipped' (expédiées = vente quasi certaine).
-- Avant expédition, une commande peut encore être annulée.
-- Exception : les analyses de délais de livraison ne portent que sur 'delivered'.


-- ------------------------------------------------------------
-- 4. Période couverte
-- ------------------------------------------------------------

SELECT
    strftime('%Y-%m', order_purchase_timestamp) AS mois,
    COUNT(DISTINCT order_id)                    AS nb_commandes
FROM orders
GROUP BY mois
ORDER BY mois;
-- Résultat : de 2016-09 à 2018-10, mais :
-- - 2016 : quelques centaines de commandes seulement, et aucun mois de novembre 2016
-- - 2018-09 et 2018-10 : 16 et 4 commandes, contre plus de 6 000 par mois juste avant
-- => Une chute aussi brutale indique des données incomplètes (date d'extraction
--    du jeu de données), pas une baisse réelle de l'activité.
-- Choix retenu : les analyses par mois portent sur janvier 2017 - août 2018 (20 mois complets).


-- ------------------------------------------------------------
-- 5. Qualité des données : commandes sans aucun article
-- ------------------------------------------------------------

SELECT
    o.order_status,
    COUNT(*) AS nb_commandes_sans_article
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY nb_commandes_sans_article DESC;
-- Résultat : très majoritairement 'unavailable' et 'canceled' (logique : jamais abouties),
-- plus une poignée de 'created', 'invoiced' et 1 'shipped'.
-- Ces commandes existent dans orders mais n'ont aucun article enregistré
-- (anomalie d'export ou commandes de test probables).
-- Impact négligeable sur l'analyse : conservées telles quelles, signalées dans le README.


-- ============================================================
-- Synthèse de l'étape 1
-- - 96 096 clients réels (customer_unique_id) pour 99 441 commandes
-- - Périmètre retenu : statuts 'delivered' et 'shipped'
-- - Période d'analyse mensuelle : janvier 2017 - août 2018
-- - Première observation : très peu de clients repassent commande
-- ============================================================
