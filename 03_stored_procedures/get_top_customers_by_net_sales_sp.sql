
-- ============================================================
-- Stored Procedure: get_top_customers_by_net_sales
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Return top N customers by net sales for a given
--          market and fiscal year
-- Parameters:
--   in_market      (VARCHAR 45) — target market e.g. "India"
--   in_fiscal_year (INT)        — target fiscal year e.g. 2021
--   in_top_n       (INT)        — number of results to return
-- Architecture: 3-layer CTE pipeline
--   Layer 1 (g_price)   → Gross price total per transaction
--                         with pre-invoice discount rate
--   Layer 2 (n_i_sales) → Net invoice sales after applying
--                         pre-invoice discount
--   Layer 3 (n_sales)   → Final net sales after applying
--                         post-invoice discounts and deductions
-- Output: Top N customers ranked by net sales (in millions)
-- Dependencies: fact_sales_monthly, fact_gross_price,
--               fact_pre_invoice_deductions,
--               fact_post_invoice_deductions,
--               dim_date, dim_customer
-- Note: fiscal_year lookup uses JOIN on dim_date.calendar_date
--       (3NF compliant — no denormalized fiscal_year column)
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_top_customers_by_net_sales`(
    in_market      VARCHAR(45),
    in_fiscal_year INT,
    in_top_n       INT
)
BEGIN
    WITH 
    -- --------------------------------------------------------
    -- LAYER 1: Gross price total with pre-invoice discount rate
    -- --------------------------------------------------------
    g_price AS (
        SELECT 
            dc.market,
            dc.customer,
            fsm.customer_code,
            fsm.date,
            fsm.product_code,
            fsm.sold_quantity * fgp.gross_price AS gross_price_total,
            pid.pre_invoice_discount_pct
        FROM fact_sales_monthly fsm
        JOIN dim_customer dc
            ON dc.customer_code = fsm.customer_code
        JOIN dim_date dd
            ON dd.calendar_date = fsm.date
        JOIN fact_gross_price fgp 
            ON fsm.product_code = fgp.product_code 
            AND fgp.fiscal_year = dd.fiscal_year
        JOIN fact_pre_invoice_deductions pid
            ON fsm.customer_code = pid.customer_code 
            AND pid.fiscal_year = dd.fiscal_year
        WHERE dd.fiscal_year = in_fiscal_year 
            AND dc.market = in_market
    ),

    -- --------------------------------------------------------
    -- LAYER 2: Net invoice sales after pre-invoice discount
    -- --------------------------------------------------------
    n_i_sales AS (
        SELECT 
            market,
            customer_code,
            customer,
            date,
            product_code,
            gross_price_total - (gross_price_total * pre_invoice_discount_pct) AS net_invoice_sell
        FROM g_price	
    ),

    -- --------------------------------------------------------
    -- LAYER 3: Final net sales after post-invoice deductions
    -- --------------------------------------------------------
    n_sales AS (
        SELECT 
            market,
            customer,
            fpid.customer_code,
            fpid.date,
            fpid.product_code,
            net_invoice_sell - (net_invoice_sell * (discounts_pct + other_deductions_pct)) AS total_net_sales
        FROM n_i_sales nis
        JOIN fact_post_invoice_deductions fpid 
            ON nis.customer_code = fpid.customer_code 
            AND nis.date = fpid.date 
            AND nis.product_code = fpid.product_code
    )

    -- --------------------------------------------------------
    -- OUTPUT: Top N customers by net sales (in millions)
    -- --------------------------------------------------------
    SELECT 
        customer, 
        ROUND(SUM(total_net_sales) / 1000000, 2) AS net_sales_mln
    FROM n_sales
    GROUP BY customer
    ORDER BY net_sales_mln DESC
    LIMIT in_top_n;

END$$

DELIMITER ;
