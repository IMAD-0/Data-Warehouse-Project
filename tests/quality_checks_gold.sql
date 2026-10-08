/*
===============================================================================
Quality Checks : Gold Layer
===============================================================================
Description:
    Requêtes de validation qualité pour les vues de la couche Gold.
    Chaque check est accompagné de son objectif et du résultat attendu.

Convention :
    - [EXPECTED: 0 rows]  → la requête doit retourner 0 ligne si tout est OK
    - [EXPECTED: N rows]  → la requête doit retourner N lignes attendues
    - [INFO]              → requête informative (pas de "réussi/échoué")

Usage :
    psql -U postgres -d datawarehouse -f scripts/quality_check_gold.sql
===============================================================================
*/


--############################################################
--# 1. gold.dim_customers
--############################################################

--=======================================
-- Check 1.1 : Unicité de customer_id
-- Objectif  : chaque cst_id doit apparaître une seule fois
-- Attendu   : 0 ligne (aucun doublon)
--=======================================
SELECT
    cst_id,
    COUNT(*) AS nb_occurrences
FROM gold.dim_customers
GROUP BY cst_id
HAVING COUNT(*) > 1;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 1.2 : Unicité de customer_key (surrogate key)
-- Objectif  : la clé de substitution doit être unique
-- Attendu   : 0 ligne
--=======================================
SELECT
    customer_key,
    COUNT(*) AS nb_occurrences
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 1.3 : Intégrité du customer_number (cst_key)
-- Objectif  : pas de NULL ni de doublons sur la clé naturelle
-- Attendu   : 0 ligne
--=======================================
SELECT
    customer_number,
    COUNT(*) AS nb_occurrences
FROM gold.dim_customers
WHERE customer_number IS NULL
   OR customer_number IN (
       SELECT customer_number
       FROM gold.dim_customers
       GROUP BY customer_number
       HAVING COUNT(*) > 1
   )
GROUP BY customer_number;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 1.4 : Mapping du genre CRM vs ERP
-- Objectif  : vérifier la cohérence de la normalisation du genre
-- Attendu   : toutes les valeurs de new_gender ∈ ('MALE', 'FEMALE', 'n/a')
--=======================================
SELECT DISTINCT
    ci.cst_gndr                                    AS crm_gender,
    az.gen                                         AS erp_gender,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN UPPER(ci.cst_gndr)
        ELSE COALESCE(az.gen, 'n/a')
    END                                            AS new_gender
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS az ON az.cid = ci.cst_key
ORDER BY 1, 2;
-- [INFO]


--=======================================
-- Check 1.5 : Valeurs finales du genre dans Gold
-- Objectif  : s'assurer qu'aucune valeur inattendue n'existe
-- Attendu   : seulement 'MALE', 'FEMALE', 'n/a'
--=======================================
SELECT
    gender,
    COUNT(*) AS nb
FROM gold.dim_customers
GROUP BY gender
ORDER BY nb DESC;
-- [INFO]


--=======================================
-- Check 1.6 : Bornes de birthday (date de naissance)
-- Objectif  : détecter les dates futures ou trop anciennes
-- Attendu   : 0 ligne
--=======================================
SELECT *
FROM gold.dim_customers
WHERE birthday > CURRENT_DATE
   OR birthday < DATE '1900-01-01';
-- [EXPECTED: 0 rows]


--############################################################
--# 2. gold.dim_products
--############################################################

--=======================================
-- Check 2.1 : Unicité de product_id
-- Objectif  : chaque prd_id doit apparaître une seule fois
-- Attendu   : 0 ligne
--=======================================
SELECT
    product_id,
    COUNT(*) AS nb_occurrences
FROM gold.dim_products
GROUP BY product_id
HAVING COUNT(*) > 1;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 2.2 : Unicité de product_key (surrogate key)
-- Objectif  : la clé de substitution doit être unique
-- Attendu   : 0 ligne
--=======================================
SELECT
    product_key,
    COUNT(*) AS nb_occurrences
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 2.3 : Absence de NULL sur les clés
-- Objectif  : product_id et product_number ne doivent jamais être NULL
-- Attendu   : 0 ligne
--=======================================
SELECT *
FROM gold.dim_products
WHERE product_id     IS NULL
   OR product_number IS NULL;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 2.4 : Cohérence du filtre historique
-- Objectif  : la vue ne doit contenir que les produits ACTIFS
--             (prd_end_dt IS NULL dans silver)
-- Attendu   : 0 ligne
--=======================================
SELECT pi.*
FROM gold.dim_products gp
JOIN silver.crm_prd_info pi ON pi.prd_id = gp.product_id
WHERE pi.prd_end_dt IS NOT NULL;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 2.5 : Cohérence du prix (cost)
-- Objectif  : le coût ne doit jamais être NULL (remplacé par 0)
-- Attendu   : 0 ligne
--=======================================
SELECT *
FROM gold.dim_products
WHERE cost IS NULL;
-- [EXPECTED: 0 rows]


--############################################################
--# 3. gold.fact_sales
--############################################################

--=======================================
-- Check 3.1 : Intégrité référentielle — product_key
-- Objectif  : chaque vente doit pointer vers un produit existant
-- Attendu   : 0 ligne (orphelins = données invalides)
--=======================================
SELECT s.*
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p ON p.product_key = s.product_key
WHERE p.product_key IS NULL;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 3.2 : Intégrité référentielle — customer_key
-- Objectif  : chaque vente doit pointer vers un client existant
-- Attendu   : 0 ligne
--=======================================
SELECT s.*
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c ON c.customer_key = s.customer_key
WHERE c.customer_key IS NULL;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 3.3 : Absence de NULL sur les mesures
-- Objectif  : sales_amount, quantity, price ne doivent pas être NULL
-- Attendu   : 0 ligne
--=======================================
SELECT *
FROM gold.fact_sales
WHERE sales_amount IS NULL
   OR quantity     IS NULL
   OR price        IS NULL;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 3.4 : Cohérence de la formule sales = quantity × price
-- Objectif  : vérifier que sales_amount = quantity * price
-- Attendu   : 0 ligne
--=======================================
SELECT
    order_number,
    sales_amount,
    quantity,
    price,
    quantity * price AS calculated
FROM gold.fact_sales
WHERE sales_amount != quantity * price;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 3.5 : Cohérence des dates de commande
-- Objectif  : order_date <= ship_date <= due_date
-- Attendu   : 0 ligne
--=======================================
SELECT *
FROM gold.fact_sales
WHERE order_date > ship_date
   OR ship_date  > due_date;
-- [EXPECTED: 0 rows]


--=======================================
-- Check 3.6 : Absence de NULL sur les dates critiques
-- Objectif  : order_date ne doit pas être NULL
-- Attendu   : 0 ligne
--=======================================
SELECT *
FROM gold.fact_sales
WHERE order_date IS NULL;
-- [EXPECTED: 0 rows]
