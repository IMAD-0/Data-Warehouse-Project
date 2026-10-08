/*
===============================================================================
DDL : Gold Layer Views (Data Warehouse)
===============================================================================
Description:
    Crée les vues de la couche Gold (schéma étoile) :
      - gold.dim_customers : dimension clients
      - gold.dim_products  : dimension produits (historique filtré)
      - gold.fact_sales    : table de faits ventes

Prérequis :
    - Schéma silver chargé (silver.load_silver)
    - Les tables silver.* doivent exister

Ordre d'exécution :
    Les vues sont créées dans l'ordre des dépendances :
    dim_customers → dim_products → fact_sales (qui dépend des 2 dims)

===============================================================================
*/

-- Création du schéma gold si absent
CREATE SCHEMA IF NOT EXISTS gold;

-- Suppression dans l'ordre inverse des dépendances (fact_sales dépend des dims)
DROP VIEW IF EXISTS gold.fact_sales    CASCADE;
DROP VIEW IF EXISTS gold.dim_products  CASCADE;
DROP VIEW IF EXISTS gold.dim_customers CASCADE;


--=======================================
-- View : gold.dim_customers
--=======================================

CREATE OR REPLACE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id)          AS customer_key,
    ci.cst_id                                        AS customer_id,
    ci.cst_key                                       AS customer_number,
    ci.cst_firstname                                 AS first_name,
    ci.cst_lastname                                  AS last_name,
    ci.cst_marital_status                            AS marital_status,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN UPPER(ci.cst_gndr)
        ELSE COALESCE(az.gen, 'n/a')
    END                                              AS gender,
    az.bdate                                         AS birthday,
    la.cntry                                         AS country,
    ci.cst_create_date                               AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS az ON az.cid = ci.cst_key
LEFT JOIN silver.erp_loc_a101  AS la ON la.cid = ci.cst_key;


--=======================================
-- View : gold.dim_products
--=======================================

CREATE OR REPLACE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pi.prd_id, pi.prd_key) AS product_key,
    pi.prd_id                                          AS product_id,
    pi.prd_key                                         AS product_number,
    pi.prd_nm                                          AS product_name,
    pi.cat_id                                          AS category_id,
    p.cat                                              AS category,
    p.subcat                                           AS subcategory,
    p.maintenance,
    pi.prd_cost                                        AS cost,
    pi.prd_line                                        AS product_line,
    pi.prd_start_dt                                    AS start_date
FROM silver.crm_prd_info AS pi
LEFT JOIN silver.erp_px_cat_g1v2 AS p ON p.id = pi.cat_id
WHERE pi.prd_end_dt IS NULL;   -- ne garde que la version active du produit


--=======================================
-- View : gold.fact_sales
--=======================================

CREATE OR REPLACE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num         AS order_number,
    p.product_key,
    c.customer_key,
    sd.sls_sales           AS sales_amount,
    sd.sls_quantity        AS quantity,
    sd.sls_price           AS price,
    sd.sls_order_dt        AS order_date,
    sd.sls_ship_dt         AS shipping_date,   
    sd.sls_due_dt          AS due_date
FROM silver.crm_sales_details AS sd
LEFT JOIN gold.dim_customers AS c ON c.customer_id    = sd.sls_cust_id
LEFT JOIN gold.dim_products  AS p ON p.product_number = sd.sls_prd_key;   