-- ============================================================
-- Stored Procedure: get_net_sales_by_fiscal_year
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Calculate net sales per market for a given fiscal
--          year after applying pre and post-invoice deductions
-- Parameter:
--   in_fiscal_year (INT) — target fiscal year e.g. 2021
-- Enhancement over exploration query:
--   + Removed hardcoded fiscal year → parameterized input
--   + Added dim_customer JOIN → results grouped by market
--   + Output scaled to millions (/ 1000000) for readability
--   + Returns top 5 markets by net sales
-- Dependencies: fact_sales_monthly, fact_gross_price,
--               fact_pre_invoice_deductions,
--               fact_post_invoice_deductions,
--               dim_date, dim_customer
-- Note: fiscal_year lookup uses JOIN on dim_date.calendar_date
--       (3NF compliant — no denormalized fiscal_year column)
-- ============================================================

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_net_sales_by_fiscal_year`(
    in_fiscal_year INT
)
BEGIN
    WITH 
    -- --------------------------------------------------------
    -- LAYER 1: Gross price total with pre-invoice discount rate
    -- --------------------------------------------------------
    g_price AS (
        SELECT 
            dc.market,
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
    ),

    -- --------------------------------------------------------
    -- LAYER 2: Net invoice sales after pre-invoice discount
    -- --------------------------------------------------------
    n_i_sales AS (
        SELECT 
            market,
            customer_code,
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
    -- OUTPUT: Top 5 markets by net sales (in millions)
    -- --------------------------------------------------------
    SELECT 
        market, 
        ROUND(SUM(total_net_sales) / 1000000, 2) AS net_sales_mln
    FROM n_sales
    GROUP BY market
    ORDER BY net_sales_mln DESC
    LIMIT 5;

END
