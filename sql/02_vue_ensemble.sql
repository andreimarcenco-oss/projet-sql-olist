-- ============================================================
-- Projet Olist : analyse clients d'un site e-commerce
-- 02 - Vue d'ensemble de l'activité
-- Définitions :
-- - CA = SUM(order_items.price) : chiffre d'affaires produits, hors frais de port (en R$)
--   (order_payments non utilisé : inclut les frais de port, non relié aux produits,
--    et plusieurs lignes de paiement par commande dupliqueraient les articles en jointure)
-- - Périmètre : statuts 'delivered' et 'shipped', commandes de janvier 2017 à août 2018
-- ============================================================


-- ------------------------------------------------------------
-- 1. CA total et nombre de commandes sur la période
-- ------------------------------------------------------------

SELECT
    SUM(oi.price)              AS ca,
    COUNT(DISTINCT o.order_id) AS nb_commandes   -- DISTINCT : une commande a plusieurs lignes d'articles
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status IN ('delivered', 'shipped')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';
-- Résultat : 13 330 627 R$ de CA pour 97 308 commandes

-- Pièges évités :
-- - COUNT(o.order_id) sans DISTINCT comptait les articles, pas les commandes
-- - comparer strftime('%Y-%m', ...) à une date complète ('2017-01-01') fausse le filtre
--   (comparaison de textes) : on compare toujours la date complète à une date complète


-- ------------------------------------------------------------
-- 2. CA et nombre de commandes par mois
-- ------------------------------------------------------------

SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS mois,
    ROUND(SUM(oi.price), 0)                       AS ca,
    COUNT(DISTINCT o.order_id)                    AS nb_commandes
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status IN ('delivered', 'shipped')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY mois
ORDER BY mois;
-- Résultat : 20 mois, de 114 197 R$ (janvier 2017) à 995 029 R$ (novembre 2017)


-- ------------------------------------------------------------
-- 3. Panier moyen par mois
-- ------------------------------------------------------------

SELECT
    strftime('%Y-%m', o.order_purchase_timestamp)              AS mois,
    ROUND(SUM(oi.price), 0)                                    AS ca,
    COUNT(DISTINCT o.order_id)                                 AS nb_commandes,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2)       AS panier_moyen
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status IN ('delivered', 'shipped')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY mois
ORDER BY mois;


-- Variabilité du panier moyen mensuel sur les 20 mois
WITH par_mois AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp)        AS mois,
        SUM(oi.price) / COUNT(DISTINCT o.order_id)           AS panier_moyen
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status IN ('delivered', 'shipped')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY mois
)
SELECT
    ROUND(MIN(panier_moyen), 2)                              AS panier_min,
    ROUND(MAX(panier_moyen), 2)                              AS panier_max,
    ROUND((MAX(panier_moyen) / MIN(panier_moyen) - 1) * 100, 1) AS ecart_max_min_pct
FROM par_mois;
-- Résultat : de 124,48 R$ (juillet 2017) à 149,08 R$ (janvier 2017), écart de +19,8 %
-- Panier moyen global sur la période : 13 330 627 / 97 308 = environ 137 R$
-- (et non la moyenne des 20 paniers mensuels : une moyenne de moyennes
--  donne le même poids à chaque mois, quel que soit son nombre de commandes)

-- Lecture :
-- - Le panier moyen est stable (environ ±10 % autour de 137 R$) alors que le CA
--   est multiplié par 8 : la croissance vient du nombre de commandes, pas du prix.
-- - Novembre 2017 (Black Friday) : CA +52 % vs octobre, mais panier en légère baisse
--   (145 -> 135 R$) avec près de 2 900 commandes de plus : les clients ont acheté
--   plus souvent, pas plus cher. Hypothèse cohérente : prix réduits pendant le Black Friday.


-- ------------------------------------------------------------
-- 4. Évolution du CA d'un mois sur l'autre (%)
-- ------------------------------------------------------------

WITH par_mois AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp)        AS mois,
        COUNT(DISTINCT o.order_id)                           AS nb_commandes,
        ROUND(SUM(oi.price), 0)                              AS ca,
        ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS panier_moyen
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status IN ('delivered', 'shipped')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY mois
)
SELECT
    mois,
    nb_commandes,
    ca,
    LAG(ca) OVER (ORDER BY mois)                             AS ca_mois_precedent,
    ROUND((ca - LAG(ca) OVER (ORDER BY mois)) * 100.0
          / LAG(ca) OVER (ORDER BY mois), 2)                 AS evolution_pct,
    panier_moyen
FROM par_mois
ORDER BY mois;
-- Résultat : janvier 2017 = NULL (pas de mois précédent), novembre 2017 = +52,16 %


-- ============================================================
-- Synthèse de l'étape 2
-- 1. Forte croissance en 2017 (CA x8 entre janvier et décembre), portée par le
--    nombre de commandes ; le panier moyen reste stable autour de 137 R$.
--    (Les fortes hausses du début s'expliquent en partie par l'effet de base.)
-- 2. Pic du Black Friday en novembre 2017 (+52 % vs octobre) : plus de commandes,
--    panier légèrement plus bas. Recul de 26 % en décembre.
-- 3. Plateau en 2018 : pic en avril-mai (environ 990 000 R$) puis léger recul
--    (environ 850 000 - 870 000 R$ de juin à août). La croissance s'essouffle.
-- Hypothèses à confirmer : effet fête des Mères au Brésil (mai), rebond de janvier
-- après le creux de décembre.
-- Question ouverte pour l'étape 3 : la croissance repose-t-elle uniquement sur
-- l'acquisition de nouveaux clients ?
-- ============================================================
