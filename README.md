# Analyse clients d'un site e-commerce : Olist

> **Projet en cours.** Étapes 1 et 2 terminées, les suivantes arrivent au fil de l'eau.

## Le contexte

[Olist](https://olist.com/) est une marketplace brésilienne qui permet à des vendeurs de diffuser leurs produits sur les grands sites e-commerce du pays.
Je me place dans la peau d'un data analyst de l'entreprise, chargé de répondre à la direction :

**« Qui sont nos clients, est-ce qu'ils reviennent, et qu'est-ce qui les fait partir ? »**

## Les données

- Source : [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)
- Environ 100 000 commandes passées entre 2016 et 2018, réparties en 8 tables : commandes, articles, paiements, avis, clients, produits, vendeurs, traduction des catégories
- Base SQLite interrogée avec DBeaver (la base n'est pas incluse dans ce dépôt, voir le lien ci-dessus)

## Les choix de méthode

| Sujet | Choix retenu | Pourquoi |
|---|---|---|
| Identifiant client | `customer_unique_id` | `customer_id` est recréé à chaque commande : l'utiliser ferait croire qu'aucun client ne revient |
| Chiffre d'affaires | `SUM(order_items.price)`, hors frais de port, en réals (R$) | Seul `order_items` relie les ventes aux produits ; les paiements incluent le port et ont plusieurs lignes par commande |
| Commandes retenues | Statuts `delivered` et `shipped` | Avant l'expédition, une commande peut encore être annulée |
| Période d'analyse mensuelle | Janvier 2017 à août 2018 | 2016 et septembre-octobre 2018 sont incomplets (date d'extraction des données) |

## Les premiers résultats

**1. Les clients ne reviennent presque pas.** 96 096 clients pour 99 441 commandes : l'immense majorité ne commande qu'une seule fois.

**2. Une forte croissance en 2017, portée par le nombre de commandes.** Le CA est multiplié par 8 entre janvier et décembre 2017, alors que le panier moyen reste stable autour de 137 R$.

**3. Un pic au Black Friday.** En novembre 2017, le CA bondit de 52 % par rapport à octobre : plus de commandes, avec un panier légèrement plus bas.

**4. Un plateau en 2018.** Le CA culmine en avril-mai (environ 990 000 R$ par mois) puis recule légèrement : la croissance s'essouffle.

**Question ouverte :** si les clients ne reviennent pas, la croissance repose entièrement sur l'acquisition de nouveaux clients. C'est l'objet de l'étape suivante.

## Qualité des données

- 775 commandes n'ont aucun article enregistré, presque toutes annulées ou indisponibles (dont 1 commande expédiée) : impact négligeable, conservées telles quelles.

## Avancement

- [x] 01 - Découverte des données : [`sql/01_decouverte.sql`](sql/01_decouverte.sql)
- [x] 02 - Vue d'ensemble : CA, commandes, panier moyen, évolution mensuelle : [`sql/02_vue_ensemble.sql`](sql/02_vue_ensemble.sql)
- [ ] 03 - Fidélité : part des clients qui reviennent et délai de retour
- [ ] 04 - Segmentation RFM des clients
- [ ] 05 - Livraison et satisfaction : les retards font-ils baisser les notes ?
- [ ] 06 - Catégories : ce qui rapporte et ce qui déçoit
- [ ] 07 - Tableau de bord Power BI et recommandations

## Outils

SQL (SQLite) · DBeaver · Power BI (à venir)

## Auteur

**Andrei Marcenco** : diplômé de Grenoble École de Management, en reconversion vers l'analyse de données.
