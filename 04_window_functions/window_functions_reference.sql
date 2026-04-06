-- ============================================================
-- Window Functions Reference — gdb0041 (AtliQ Hardware)
-- Purpose: Demonstrate core window function concepts applied
--          throughout this repository's stored procedures
-- Functions covered:
--   1. OVER() and PARTITION BY        — basic windowing
--   2. RANK()                         — ranking with gaps
--   3. DENSE_RANK()                   — ranking without gaps
--   4. ROW_NUMBER()                   — unique sequential rank
--   5. RANK vs DENSE_RANK vs ROW_NUMBER — side-by-side
--   6. LAG()                          — access previous row
--   7. LEAD()                         — access next row
-- All examples use gdb0041 schema tables
-- See stored procedures for production usage of these
-- concepts:
--   DENSE_RANK → 03_stored_procedures/
--                get_top_n_products_per_division_by_qty_sold_sp.sql
--   LAG        → 03_stored_procedures/
--                forecast_accuracy_between_years_LAG_sp.sql
-- ============================================================


-- ============================================================
-- 1. OVER() AND PARTITION BY
-- Basic window function syntax — calculates a value across
-- a defined partition without collapsing rows like GROUP BY
-- ============================================================

-- Total sold quantity per division shown alongside each
-- individual product row — GROUP BY would lose the product
-- detail; OVER(PARTITION BY) keeps all rows intact
SELECT 
    dp.division,
    dp.product,
    SUM(fsm.sold_quantity) OVER (
        PARTITION BY dp.division
    ) AS total_qty_by_division
FROM fact_sales_monthly fsm
JOIN dim_product dp
    ON fsm.product_code = dp.product_code
JOIN dim_date dd
    ON dd.calendar_date = fsm.date
WHERE dd.fiscal_year = 2021
ORDER BY dp.division, dp.product;


-- ============================================================
-- 2. RANK()
-- Assigns rank within partition ordered by a value
-- RANK() leaves gaps after ties:
--   e.g. 1, 2, 2, 4 (position 3 skipped after tie at 2)
-- ============================================================

SELECT 
    dp.division,
    dp.product,
    SUM(fsm.sold_quantity) AS total_qty,
    RANK() OVER (
        PARTITION BY dp.division
        ORDER BY SUM(fsm.sold_quantity) DESC
    ) AS rnk
FROM fact_sales_monthly fsm
JOIN dim_product dp
    ON fsm.product_code = dp.product_code
JOIN dim_date dd
    ON dd.calendar_date = fsm.date
WHERE dd.fiscal_year = 2021
GROUP BY dp.division, dp.product
ORDER BY dp.division, rnk;


-- ============================================================
-- 3. DENSE_RANK()
-- Same as RANK() but NO gaps after ties:
--   e.g. 1, 2, 2, 3 (position 3 follows immediately)
-- Used in: get_top_n_products_per_division_by_qty_sold_sp.sql
--   Chosen over RANK() to ensure exactly in_top_n products
--   per division are returned even when quantities tie
-- ============================================================

SELECT 
    dp.division,
    dp.product,
    SUM(fsm.sold_quantity) AS total_qty,
    DENSE_RANK() OVER (
        PARTITION BY dp.division
        ORDER BY SUM(fsm.sold_quantity) DESC
    ) AS drnk
FROM fact_sales_monthly fsm
JOIN dim_product dp
    ON fsm.product_code = dp.product_code
JOIN dim_date dd
    ON dd.calendar_date = fsm.date
WHERE dd.fiscal_year = 2021
GROUP BY dp.division, dp.product
ORDER BY dp.division, drnk;


-- ============================================================
-- 4. ROW_NUMBER()
-- Assigns a unique sequential integer to every row
-- No ties possible — if values are equal, order is arbitrary
--   e.g. 1, 2, 3, 4 always (even when values are identical)
-- Use when you need exactly one row per rank position
-- ============================================================

SELECT 
    dp.division,
    dp.product,
    SUM(fsm.sold_quantity) AS total_qty,
    ROW_NUMBER() OVER (
        PARTITION BY dp.division
        ORDER BY SUM(fsm.sold_quantity) DESC
    ) AS row_num
FROM fact_sales_monthly fsm
JOIN dim_product dp
    ON fsm.product_code = dp.product_code
JOIN dim_date dd
    ON dd.calendar_date = fsm.date
WHERE dd.fiscal_year = 2021
GROUP BY dp.division, dp.product
ORDER BY dp.division, row_num;


-- ============================================================
-- 5. RANK vs DENSE_RANK vs ROW_NUMBER — side by side
-- Run this to see the difference in one result set
-- Useful when two products tie on quantity:
--   RANK       → 1, 2, 2, 4   (gap after tie)
--   DENSE_RANK → 1, 2, 2, 3   (no gap after tie)
--   ROW_NUMBER → 1, 2, 3, 4   (always unique)
-- ============================================================

SELECT 
    dp.division,
    dp.product,
    SUM(fsm.sold_quantity) AS total_qty,
    RANK()       OVER (PARTITION BY dp.division ORDER BY SUM(fsm.sold_quantity) DESC) AS rnk,
    DENSE_RANK() OVER (PARTITION BY dp.division ORDER BY SUM(fsm.sold_quantity) DESC) AS drnk,
    ROW_NUMBER() OVER (PARTITION BY dp.division ORDER BY SUM(fsm.sold_quantity) DESC) AS row_num
FROM fact_sales_monthly fsm
JOIN dim_product dp
    ON fsm.product_code = dp.product_code
JOIN dim_date dd
    ON dd.calendar_date = fsm.date
WHERE dd.fiscal_year = 2021
GROUP BY dp.division, dp.product
ORDER BY dp.division, drnk;


-- ============================================================
-- 6. LAG()
-- Accesses the value from the PREVIOUS row within a partition
-- LAG(column, offset, default)
--   offset  → how many rows back (default 1)
--   default → value if no previous row exists (default NULL)
-- Used in: forecast_accuracy_between_years_LAG_sp.sql
--   Retrieves y1 accuracy alongside the y2 row for each
--   customer to enable year-over-year comparison
-- ============================================================

-- Year-over-year net sales comparison per market
-- LAG() retrieves previous year's sales on the current row
SELECT 
    dc.market,
    dd.fiscal_year,
    ROUND(SUM(fsm.sold_quantity * fgp.gross_price) / 1000000, 2) AS gross_sales_mln,
    LAG(ROUND(SUM(fsm.sold_quantity * fgp.gross_price) / 1000000, 2)) OVER (
        PARTITION BY dc.market
        ORDER BY dd.fiscal_year
    ) AS prev_year_sales_mln
FROM fact_sales_monthly fsm
JOIN dim_customer dc
    ON fsm.customer_code = dc.customer_code
JOIN dim_date dd
    ON dd.calendar_date = fsm.date
JOIN fact_gross_price fgp
    ON fsm.product_code = fgp.product_code
    AND fgp.fiscal_year = dd.fiscal_year
GROUP BY dc.market, dd.fiscal_year
ORDER BY dc.market, dd.fiscal_year;


-- ============================================================
-- 7. LEAD()
-- Accesses the value from the NEXT row within a partition
-- Mirror of LAG() — looks forward instead of backward
-- LEAD(column, offset, default)
-- Useful for: identifying upcoming trends, flagging when
-- next period performance will drop below current period
-- ============================================================

-- Show each market's current year sales alongside
-- the following year's sales for forward-looking comparison
SELECT 
    dc.market,
    dd.fiscal_year,
    ROUND(SUM(fsm.sold_quantity * fgp.gross_price) / 1000000, 2) AS gross_sales_mln,
    LEAD(ROUND(SUM(fsm.sold_quantity * fgp.gross_price) / 1000000, 2)) OVER (
        PARTITION BY dc.market
        ORDER BY dd.fiscal_year
    ) AS next_year_sales_mln
FROM fact_sales_monthly fsm
JOIN dim_customer dc
    ON fsm.customer_code = dc.customer_code
JOIN dim_date dd
    ON dd.calendar_date = fsm.date
JOIN fact_gross_price fgp
    ON fsm.product_code = fgp.product_code
    AND fgp.fiscal_year = dd.fiscal_year
GROUP BY dc.market, dd.fiscal_year
ORDER BY dc.market, dd.fiscal_year;
