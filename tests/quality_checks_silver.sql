-- =========================================
-- TABLE : silver.crm_cust_info
-- =========================================

-- Check Nulls and duplicates in primary key
SELECT cst_id, COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) != 1 OR cst_id is null;

-- Check unwanted spaces
SELECT count(*)
FROM silver.crm_cust_info
WHERE trim(cst_lastname) <> cst_lastname;

SELECT count(*)
FROM silver.crm_cust_info
WHERE trim(cst_firstname) <> cst_firstname;

SELECT count(*)
FROM silver.crm_cust_info
WHERE trim(cst_gndr) <> cst_gndr;

SELECT count(*)
FROM silver.crm_cust_info
WHERE trim(cst_marital_status) <> cst_marital_status;


-- DATA Standarization & Consistency
SELECT DISTINCT cst_gndr, COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_gndr;

SELECT DISTINCT cst_marital_status, COUNT(*)
FROM silver.crm_cust_info	
GROUP BY cst_marital_status;

-- =========================================
-- TABLE : silver.crm_prd_info
-- =========================================

-- Check Nulls and duplicates in primary key
SELECT prd_id, COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) != 1 OR prd_id is null;

-- Check unwanted spaces
SELECT count(*)
FROM silver.crm_prd_info
WHERE trim(prd_nm) <> prd_nm;

SELECT count(*)
FROM silver.crm_prd_info
WHERE trim(prd_line) <> prd_line;

-- Check for null and negative numbers
SELECT * FROM silver.crm_prd_info
WHeRE prd_cost is Null OR prd_cost < 0;

-- DATA Standarization & Consistency
SELECT DISTINCT prd_line, COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_line;

-- Check start and end date
SELECT *
FROM silver.crm_prd_info
WHeRE prd_end_dt < prd_start_dt;


-- =========================================
-- TABLE : silver.crm_sales_details
-- =========================================
SELECT *
FROM silver.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

SELECT *
FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

-- DATE format


-- order_date must be earlier than ship_date and de_date
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Business Rule : sales = quantity * price (A)
-- Negatives, Zeros, Nulls Not Allowed
-- if sales <= 0 OR Null , then use the (A)
-- if price is = 0 OR Null, then use the (A)
-- if price is < 0, then make it positive
SELECT *
FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price 
	  OR sls_price IS null 
	  OR sls_sales IS null 
	  OR sls_quantity IS null

SELECT *
FROM silver.crm_sales_details
WHERE sls_price <= 0 
	  OR sls_sales <= 0
	  OR sls_quantity <= 0	  


-- =========================================
-- TABLE : silver.erp_cust_az12
-- =========================================

-- validate id
SELECT *
FROM silver.erp_cust_az12
WHERE cid not in (SELECT cst_key FROM silver.crm_cust_info);

-- Outlliers date
SELECT bdate
FROM silver.erp_cust_az12
WHERE bdate < '1926-01-01' OR bdate > CURRENT_DATE

-- data standarization
SELECT DISTINCT gen
FROM silver.erp_cust_az12

SELECT COUNT(*)
FROM silver.erp_cust_az12
WHERE gen is null


-- =========================================
-- TABLE : silver.erp_loc_a101
-- =========================================

-- check id
SELECT cid, cntry
FROM silver.erp_loc_a101
where cid not in (select cst_key from bronze.crm_cust_info)

-- check country
SELECT DISTINCT cntry
FROM silver.erp_loc_a101

-- =========================================
-- TABLE : silver.erp_px_cat_g1v2
-- =========================================

SELECT  *
FROM bronze.erp_px_cat_g1v2
WHERE id not in (SELECT cat_id FROM silver.crm_prd_info)

SELECT DISTINCT cat
FROM bronze.erp_px_cat_g1v2

SELECT DISTINCT subcat
FROM bronze.erp_px_cat_g1v2
ORDER BY subcat

SELECT DISTINCT maintenance
FROM bronze.erp_px_cat_g1v2