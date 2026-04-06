-- ============================================================
-- Monthly Gross Sales Report — Croma India
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Calculate monthly gross sales for Croma India
--          using fact_gross_price and fact_sales_monthly
-- Approach 1: Direct JOIN with hardcoded customer code
-- Approach 2: CTE version with named customer lookup
-- ============================================================


-- APPROACH 1: Direct query
SELECT 
    fsm.date, 
    ROUND(SUM(fgp.gross_price * fsm.sold_quantity), 2) AS gross_sales_amount
FROM fact_sales_monthly fsm
JOIN fact_gross_price AS fgp
    ON fgp.product_code = fsm.product_code
WHERE customer_code = "90002002" 
    AND fgp.fiscal_year = get_fiscal_year(date)
GROUP BY fsm.date;

-- APPROACH 2: CTE version with named customer lookup
WITH
    customer_name AS (
        SELECT customer, market, customer_code
        FROM dim_customer
        WHERE customer = "Croma" AND market = "India"
    ),
    gross_sales_amount AS (
        SELECT fsm.date, fgp.gross_price, fsm.sold_quantity
        FROM fact_gross_price AS fgp
        JOIN fact_sales_monthly AS fsm
            ON fgp.product_code = fsm.product_code
        WHERE fgp.fiscal_year = get_fiscal_year(date) 
            AND customer_code IN (
                SELECT customer_code FROM customer_name
            )
    )
SELECT 
    date, 
    ROUND(SUM(gross_price * sold_quantity), 2) AS total_gross_sales_amount
FROM gross_sales_amount
GROUP BY date;
