-- ============================================================
-- Stored Procedure: get_top_n_products_per_division_by_qty_sold
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Return top N products per division ranked by
--          total quantity sold for a given fiscal year
-- Parameters:
--   in_fiscal_year (INT) — target fiscal year e.g. 2021
--   in_top_n       (INT) — number of top products per division
-- Architecture: 2-layer CTE + window function
--   Layer 1 (sold_qty) → Total quantity sold per product
--                        grouped by division and product
--   Layer 2 (top_rank) → DENSE_RANK() applied within each
--                        division partition ordered by qty desc
--   Filter            → WHERE drnk <= in_top_n returns exactly
--                        top N per division
-- Key technique: DENSE_RANK() with PARTITION BY division
--   Resets rank counter for each division independently
--   DENSE_RANK used over RANK to avoid gaps when qty ties occur
-- Output: Top N products per division with rank included
-- Difference from get_top_n_products_by_net_sales:
--   Ranks by quantity sold, not revenue
--   Partitions by division — independent ranking per group
--   No deduction pipeline needed — uses raw sold_quantity
-- Dependencies: fact_sales_monthly, dim_product, dim_date
-- Note: fiscal_year lookup uses JOIN on dim_date.calendar_date
--       (3NF compliant — no denormalized fiscal_year column)
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_top_n_products_per_division_by_qty_sold`(
    in_fiscal_year INT,
    in_top_n       INT
)
BEGIN
    WITH 
    -- --------------------------------------------------------
    -- LAYER 1: Total quantity sold per product per division
    -- --------------------------------------------------------
    sold_qty AS (
        SELECT 
            dp.division,
            dp.product,
            SUM(sold_quantity) AS total_qty
        FROM fact_sales_monthly fsm
        JOIN dim_product dp
            ON fsm.product_code = dp.product_code
        JOIN dim_date dd
            ON dd.calendar_date = fsm.date
        WHERE dd.fiscal_year = in_fiscal_year
        GROUP BY dp.division, dp.product
    ),

    -- --------------------------------------------------------
    -- LAYER 2: DENSE_RANK within each division by quantity
    --          PARTITION BY division resets rank per group
    --          DENSE_RANK avoids gaps on tied quantities
    -- --------------------------------------------------------
    top_rank AS (
        SELECT 
            *,
            DENSE_RANK() OVER (
                PARTITION BY division 
                ORDER BY total_qty DESC
            ) AS drnk
        FROM sold_qty
    )

    -- --------------------------------------------------------
    -- OUTPUT: Top N products per division with rank
    -- --------------------------------------------------------
    SELECT *
    FROM top_rank
    WHERE drnk <= in_top_n;

END$$

DELIMITER ;
