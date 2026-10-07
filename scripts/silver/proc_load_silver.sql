/*
===============================================================================
Procedure: silver.load_silver()
===============================================================================
Description:
    Charge les données nettoyées et transformées depuis le schéma BRONZE
    vers le schéma SILVER (couche Silver du Data Warehouse).

Actions réalisées :
    - TRUNCATE de chaque table silver avant chargement
    - Déduplication (ROW_NUMBER)
    - Normalisation (TRIM, UPPER, CASE)
    - Nettoyage des dates (regex + bornes)
    - Gestion des NULL (COALESCE, NULLIF)
    - Calcul de colonnes dérivées (LEAD pour prd_end_dt)

Tables traitées :
    - silver.crm_cust_info
    - silver.crm_prd_info
    - silver.crm_sales_details
    - silver.erp_cust_az12
    - silver.erp_loc_a101
    - silver.erp_px_cat_g1v2

Usage :
    CALL silver.load_silver();

Prérequis :
    - Le schéma bronze doit être chargé (bronze.load_bronze)
    - Les tables silver doivent exister (ddl_silver.sql exécuté)
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    start_time        TIMESTAMP;
    end_time          TIMESTAMP;
    batch_start_time  TIMESTAMP;
    batch_end_time    TIMESTAMP;
    duration_sec      INT;
BEGIN
    batch_start_time := clock_timestamp();
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '================================================';

    -- =========================================================
    -- TABLE : silver.crm_cust_info
    -- =========================================================
    start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_cust_info';

    INSERT INTO silver.crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname,
        cst_marital_status, cst_gndr, cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname)  AS cst_lastname,
        CASE UPPER(TRIM(cst_marital_status))
            WHEN 'M' THEN 'Married'          
            WHEN 'S' THEN 'Single'
            ELSE 'n/a'
        END AS cst_marital_status,
        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            ELSE 'n/a'
        END AS cst_gndr,
        cst_create_date
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY cst_id
                   ORDER BY cst_create_date DESC
               ) AS rn
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t                                  
    WHERE rn = 1;

    end_time := clock_timestamp();
    duration_sec := EXTRACT(EPOCH FROM (end_time - start_time))::INT;
    RAISE NOTICE '>> Load Duration: % seconds', duration_sec;
    RAISE NOTICE '>> -------------';

    -- =========================================================
    -- TABLE : silver.crm_prd_info
    -- =========================================================
    start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_prd_info';

    INSERT INTO silver.crm_prd_info (
        prd_id, cat_id, prd_key, prd_nm,
        prd_cost, prd_line, prd_start_dt, prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
        SUBSTRING(prd_key, 7, LENGTH(prd_key))      AS prd_key,
        prd_nm,
        COALESCE(prd_cost, 0) AS prd_cost,
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,
        prd_start_dt,
        LEAD(prd_start_dt) OVER (
            PARTITION BY prd_key
            ORDER BY prd_start_dt
        ) - 1 AS prd_end_dt
    FROM bronze.crm_prd_info;

    end_time := clock_timestamp();
    duration_sec := EXTRACT(EPOCH FROM (end_time - start_time))::INT;
    RAISE NOTICE '>> Load Duration: % seconds', duration_sec;
    RAISE NOTICE '>> -------------';

    -- =========================================================
    -- TABLE : silver.crm_sales_details
    -- =========================================================
    start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_sales_details';

    INSERT INTO silver.crm_sales_details (
        sls_ord_num, sls_prd_key, sls_cust_id,
        sls_order_dt, sls_ship_dt, sls_due_dt,
        sls_sales, sls_quantity, sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE
            WHEN sls_order_dt::TEXT ~ '^\d{8}$'
                 AND sls_order_dt BETWEEN 19000101 AND 99991231
                THEN TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD')
            ELSE NULL
        END AS sls_order_dt,
        CASE
            WHEN sls_ship_dt::TEXT ~ '^\d{8}$'
                 AND sls_ship_dt BETWEEN 19000101 AND 99991231
                THEN TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD')
            ELSE NULL
        END AS sls_ship_dt,
        CASE
            WHEN sls_due_dt::TEXT ~ '^\d{8}$'
                 AND sls_due_dt BETWEEN 19000101 AND 99991231
                THEN TO_DATE(sls_due_dt::TEXT, 'YYYYMMDD')
            ELSE NULL
        END AS sls_due_dt,
        CASE
            WHEN sls_sales IS NULL
                 OR sls_sales <= 0
                 OR sls_sales != ABS(sls_price) * sls_quantity
                THEN ABS(sls_price) * sls_quantity
            ELSE sls_sales
        END AS sls_sales,
        sls_quantity,
        CASE
            WHEN sls_price IS NULL OR sls_price = 0
                THEN ABS(sls_sales) / NULLIF(sls_quantity, 0)
            WHEN sls_price < 0
                THEN ABS(sls_price)
            ELSE sls_price
        END AS sls_price
    FROM bronze.crm_sales_details;   

    end_time := clock_timestamp();
    duration_sec := EXTRACT(EPOCH FROM (end_time - start_time))::INT;
    RAISE NOTICE '>> Load Duration: % seconds', duration_sec;
    RAISE NOTICE '>> -------------';

    -- =========================================================
    -- TABLE : silver.erp_cust_az12
    -- =========================================================
    start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;
    RAISE NOTICE '>> Inserting Data Into: silver.erp_cust_az12';

    INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
    SELECT
        CASE
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
            ELSE cid
        END AS cid,
        CASE
            WHEN bdate > CURRENT_DATE THEN NULL
            ELSE bdate
        END AS bdate,
        CASE
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'MALE'
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'FEMALE'
            ELSE 'n/a'
        END AS gen
    FROM bronze.erp_cust_az12;

    end_time := clock_timestamp();
    duration_sec := EXTRACT(EPOCH FROM (end_time - start_time))::INT;
    RAISE NOTICE '>> Load Duration: % seconds', duration_sec;
    RAISE NOTICE '>> -------------';

    -- =========================================================
    -- TABLE : silver.erp_loc_a101
    -- =========================================================
    start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;
    RAISE NOTICE '>> Inserting Data Into: silver.erp_loc_a101';

    INSERT INTO silver.erp_loc_a101 (cid, cntry)
    SELECT
        REPLACE(cid, '-', '') AS cid,
        CASE
            WHEN TRIM(cntry) IN ('USA', 'US', 'United States') THEN 'United States'
            WHEN TRIM(cntry) IN ('DE', 'Germany')              THEN 'Germany'
            WHEN cntry IS NULL OR TRIM(cntry) = ''              THEN 'n/a'
            ELSE TRIM(cntry)
        END AS cntry
    FROM bronze.erp_loc_a101;   

    end_time := clock_timestamp();
    duration_sec := EXTRACT(EPOCH FROM (end_time - start_time))::INT;
    RAISE NOTICE '>> Load Duration: % seconds', duration_sec;
    RAISE NOTICE '>> -------------';

    -- =========================================================
    -- TABLE : silver.erp_px_cat_g1v2
    -- =========================================================
    start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    RAISE NOTICE '>> Inserting Data Into: silver.erp_px_cat_g1v2';

    INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT id, cat, subcat, maintenance
    FROM bronze.erp_px_cat_g1v2;

    end_time := clock_timestamp();
    duration_sec := EXTRACT(EPOCH FROM (end_time - start_time))::INT;
    RAISE NOTICE '>> Load Duration: % seconds', duration_sec;
    RAISE NOTICE '>> -------------';

    -- =========================================================
    -- FIN DU CHARGEMENT
    -- =========================================================
    batch_end_time := clock_timestamp();
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Silver Layer is Completed';
    RAISE NOTICE '   - Total Load Duration: % seconds',
        EXTRACT(EPOCH FROM (batch_end_time - batch_start_time))::INT;
    RAISE NOTICE '================================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '================================================';
        RAISE NOTICE 'ERROR OCCURED DURING LOADING SILVER LAYER';
        RAISE NOTICE 'Error Message : %', SQLERRM;
        RAISE NOTICE 'Error Code    : %', SQLSTATE;
        RAISE NOTICE '================================================';
        RAISE;   -- Propage l'erreur (optionnel : sinon la transaction est annulée)
END;
$$;