-- ============================================
-- Load Bronze Layer (Source -> Bronze)
-- Équivalent PostgreSQL du SP bronze.load_bronze
--
-- Usage :
--   cd data-warehouse-project
--   psql -U postgres -d datawarehouse -f scripts/load_bronze.sql
--
-- IMPORTANT : exécuter depuis la RACINE du projet
-- ============================================

\set ON_ERROR_STOP on
\timing on

\echo '================================================'
\echo 'Loading Bronze Layer'
\echo '================================================'

\echo '------------------------------------------------'
\echo 'Loading CRM Tables'
\echo '------------------------------------------------'

\echo '>> Truncating Table: bronze.crm_cust_info'
TRUNCATE TABLE bronze.crm_cust_info;
\echo '>> Inserting Data Into: bronze.crm_cust_info'
\copy bronze.crm_cust_info FROM 'datasets/source_crm/cust_info.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')

\echo '>> Truncating Table: bronze.crm_prd_info'
TRUNCATE TABLE bronze.crm_prd_info;
\echo '>> Inserting Data Into: bronze.crm_prd_info'
\copy bronze.crm_prd_info FROM 'datasets/source_crm/prd_info.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')

\echo '>> Truncating Table: bronze.crm_sales_details'
TRUNCATE TABLE bronze.crm_sales_details;
\echo '>> Inserting Data Into: bronze.crm_sales_details'
\copy bronze.crm_sales_details FROM 'datasets/source_crm/sales_details.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')

\echo '------------------------------------------------'
\echo 'Loading ERP Tables'
\echo '------------------------------------------------'

\echo '>> Truncating Table: bronze.erp_loc_a101'
TRUNCATE TABLE bronze.erp_loc_a101;
\echo '>> Inserting Data Into: bronze.erp_loc_a101'
\copy bronze.erp_loc_a101 FROM 'datasets/source_erp/loc_a101.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')

\echo '>> Truncating Table: bronze.erp_cust_az12'
TRUNCATE TABLE bronze.erp_cust_az12;
\echo '>> Inserting Data Into: bronze.erp_cust_az12'
\copy bronze.erp_cust_az12 FROM 'datasets/source_erp/cust_az12.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')

\echo '>> Truncating Table: bronze.erp_px_cat_g1v2'
TRUNCATE TABLE bronze.erp_px_cat_g1v2;
\echo '>> Inserting Data Into: bronze.erp_px_cat_g1v2'
\copy bronze.erp_px_cat_g1v2 FROM 'datasets/source_erp/px_cat_g1v2.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')

\echo '=========================================='
\echo 'Loading Bronze Layer is Completed'
\echo '=========================================='