-- ============================================================
-- Net Sales Pipeline Exploration — 3-Layer CTE Architecture
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Calculate total net sales per customer after
--          applying pre-invoice and post-invoice deductions
-- Hardcoded: fiscal_year = 2021 (exploratory version)
-- Progression:
--   Layer 1 (g_price)    → Gross price total + pre-invoice
--                          discount rate per transaction
--   Layer 2 (n_i_sales)  → Net invoice sales after applying
--                          pre-invoice discount
--   Layer 3 (n_sales)    → Final net sales after applying
--                          post-invoice discounts and deductions
-- Final → Productionized as stored procedure
--         get_net_sales_by_fiscal_year_sp.sql
-- Dependencies: fact_sales_monthly, fact_gross_price,
--               fact_pre_invoice_deductions,
--               fact_post_invoice_deductions,
--               dim_date, dim_customer
-- Note: fiscal_year lookup uses JOIN on dim_date.calendar_date
--       (3NF compliant — no denormalized fiscal_year column)
-- ============================================================

WITH 
-- ------------------------------------------------------------
-- LAYER 1: Gross price total with pre-invoice discount rate
-- ------------------------------------------------------------
g_price AS (
    SELECT 
        fsm.customer_code,
        fsm.date,
        fsm.product_code,
        fsm.sold_quantity * fgp.gross_price AS gross_price_total,
        pid.pre_invoice_discount_pct
    FROM fact_sales_monthly fsm
    JOIN dim_date dd 
        ON dd.calendar_date = fsm.date
    JOIN fact_gross_price fgp 
        ON fsm.product_code = fgp.product_code 
        AND fgp.fiscal_year = dd.fiscal_year
    JOIN fact_pre_invoice_deductions pid
        ON fsm.customer_code = pid.customer_code 
        AND pid.fiscal_year = dd.fiscal_year
    WHERE dd.fiscal_year = 2021
),

-- ------------------------------------------------------------
-- LAYER 2: Net invoice sales after pre-invoice discount
-- ------------------------------------------------------------
n_i_sales AS (
    SELECT 
        customer_code,
        date,
        product_code,
        gross_price_total - (gross_price_total * pre_invoice_discount_pct) AS net_invoice_sell
    FROM g_price	
),

-- ------------------------------------------------------------
-- LAYER 3: Final net sales after post-invoice deductions
-- ------------------------------------------------------------
n_sales AS (
    SELECT 
        nis.customer_code,
        net_invoice_sell - (net_invoice_sell * (discounts_pct + other_deductions_pct)) AS total_net_sales
    FROM n_i_sales nis
    JOIN fact_post_invoice_deductions fpid 
        ON nis.customer_code = fpid.customer_code 
        AND nis.date = fpid.date 
        AND nis.product_code = fpid.product_code
)

-- ------------------------------------------------------------
-- OUTPUT: Top 5 customers by net sales
-- ------------------------------------------------------------
SELECT 
    customer_code, 
    ROUND(SUM(total_net_sales), 2) AS net_sales
FROM n_sales
GROUP BY customer_code
ORDER BY net_sales DESC
LIMIT 5;
