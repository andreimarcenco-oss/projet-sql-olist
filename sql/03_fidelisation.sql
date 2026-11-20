-- ============================================================
-- Projet Olist : analyse clients d'un site e-commerce
-- 03 - Fidélisation : les clients reviennent-ils ?
-- Définitions :
-- - Client = customer_unique_id (customer_id est recréé à chaque commande)
-- - Client récurrent = au moins 2 commandes ; occasionnel = 1 seule commande
-- - CA = SUM(order_items.price), hors frais de port (en R$)
-- - Périmètre : statuts 'delivered' et 'shipped', sur toute la période disponible
--   (pour mesurer le retour d'un client, on garde tout son historique)
-- ============================================================


-- ------------------------------------------------------------
-- 1. Répartition des clients selon leur nombre de commandes
--    (répond aussi à la question 2 : taux de clients récurrents)
-- ------------------------------------------------------------

WITH commandes AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS nb_commandes
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id   -- on joint sur la colonne commune, on affiche ce qu'on veut
    WHERE o.order_status IN ('delivered', 'shipped')
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN nb_commandes = 1 THEN '1 commande'
        WHEN nb_commandes = 2 THEN '2 commandes'
        ELSE '3 commandes ou plus'
    END                                                    AS statut_client,
    COUNT(*)                                               AS nb_clients,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM commandes), 2) AS pourcentage
FROM commandes
GROUP BY statut_client;
-- Résultat (94 399 clients) :
-- 1 commande          : 91 538 clients (96,97 %)
-- 2 commandes         :  2 629 clients (2,78 %)
-- 3 commandes ou plus :    232 clients (0,25 %)
-- => Taux de clients récurrents : 3,03 %

-- Pièges évités :
-- - joindre customers.customer_unique_id à orders.customer_id : aucune correspondance
-- - 100.0 et non 100, sinon SQLite fait une division entière (résultat 0)


-- ------------------------------------------------------------
-- 3 et 4. Part du CA et panier moyen : récurrents vs occasionnels
-- ------------------------------------------------------------

WITH commandes AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS nb_commandes,   -- DISTINCT indispensable : order_items a une ligne par article
        SUM(oi.price)              AS ca
    FROM customers c
    JOIN orders o       ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status IN ('delivered', 'shipped')
    GROUP BY c.customer_unique_id
)
SELECT
    CASE WHEN nb_commandes = 1 THEN 'occasionnel' ELSE 'recurrent' END AS statut_client,
    ROUND(SUM(ca), 2)                                                 AS ca,
    ROUND(SUM(ca) * 100.0 / (SELECT SUM(ca) FROM commandes), 2)       AS part_ca_pct,
    ROUND(SUM(ca) / SUM(nb_commandes), 2)                             AS panier_moyen
FROM commandes
GROUP BY statut_client;
-- Résultat :
-- occasionnel : 12 631 668 R$ (94,46 % du CA), panier moyen 138,00 R$
-- recurrent   :    740 558 R$ (5,54 % du CA),  panier moyen 122,47 R$

-- Pièges évités :
-- - COUNT(o.order_id) sans DISTINCT après la jointure avec order_items comptait les articles :
--   un client avec 1 commande de 3 articles était classé « récurrent » à tort
-- - panier moyen d'un groupe = SUM(ca) / SUM(nb_commandes) : les deux côtés doivent être agrégés
--   (SQLite accepte une colonne non agrégée sans erreur et prend la valeur d'une seule ligne)


-- ------------------------------------------------------------
-- 5. Délai moyen entre la 1re et la 2e commande
-- ------------------------------------------------------------

WITH commandes AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                           ORDER BY o.order_purchase_timestamp) AS place_commande,   -- 1, 2, 3... par client
        LAG(o.order_purchase_timestamp) OVER (PARTITION BY c.customer_unique_id
                           ORDER BY o.order_purchase_timestamp) AS date_precedente
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status IN ('delivered', 'shipped')
)
SELECT
    ROUND(AVG(JULIANDAY(order_purchase_timestamp) - JULIANDAY(date_precedente)), 2) AS ecart_jours
FROM commandes
WHERE place_commande = 2;   -- ne garde que les clients récurrents ; date_precedente = date de la 1re commande
-- Résultat : 80,63 jours en moyenne (2 861 clients)
-- Attention : moyenne trompeuse. Environ 31 % des 2es commandes sont passées moins d'un jour
-- après la 1re (commandes séparées le même jour, pas un vrai retour), et 17 % après plus de 6 mois.


-- ------------------------------------------------------------
-- 6. Taux de clients récurrents par état
-- ------------------------------------------------------------

WITH commandes AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS nb_commandes
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status IN ('delivered', 'shipped')
    GROUP BY c.customer_unique_id, c.customer_state
)
SELECT
    customer_state,
    COUNT(*)                                                    AS nb_clients,
    SUM(CASE WHEN nb_commandes >= 2 THEN 1 ELSE 0 END)          AS clients_recurrents,   -- comptage conditionnel
    ROUND(SUM(CASE WHEN nb_commandes >= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS taux_recurrents_pct
FROM commandes
GROUP BY customer_state
HAVING nb_clients >= 1000   -- écarte les petits états : AC affichait 5,19 % avec seulement 77 clients
ORDER BY taux_recurrents_pct DESC;
-- Résultat : parmi les 12 états de plus de 1 000 clients, le taux va de 1,62 % (CE) à 3,35 % (RJ)
-- (SP, 39 464 clients : 3,12 %)


-- ============================================================
-- Synthèse de l'étape 3
-- - 97 % des clients ne commandent qu'une fois : la fidélité est quasi inexistante.
--   C'est en partie structurel (beaucoup de clients ne savent pas qu'ils achètent via Olist,
--   produits peu fréquents), mais 94 % du CA dépend de clients qui ne reviennent jamais :
--   la croissance repose entièrement sur l'acquisition.
-- - Un client récurrent pèse environ 1,8 fois un occasionnel (5,54 % du CA pour 3,03 % des clients),
--   uniquement grâce à la fréquence : son panier moyen est même plus bas (122 R$ contre 138 R$).
-- - Le délai moyen de retour (81 jours) cache deux comportements : commandes le même jour
--   et vrais retours plusieurs mois plus tard.
-- - La géographie n'explique pas la faible fidélité (taux proches dans les grands états) :
--   piste suivante, l'expérience client (délais de livraison, avis).
-- ============================================================
