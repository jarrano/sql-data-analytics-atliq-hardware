-- ============================================================
-- Stored Procedure: get_monthly_gross_sales_for_customer
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Calculate monthly gross sales total for one or
--          multiple customers passed as a comma-separated list
-- Parameter:
--   in_customer_codes (TEXT) — comma-separated customer codes
--                              e.g. "90002002" or "90002002,90002003"
-- Technique: FIND_IN_SET() for multi-value TEXT parameter lookup
-- Dependencies: fact_sales_monthly, fact_gross_price,
--               get_fiscal_year() function
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_monthly_gross_sales_for_customer`(
    in_customer_codes TEXT
)
BEGIN
    SELECT 
        s.date,
        SUM(g.gross_price * s.sold_quantity) AS gross_price_total
    FROM fact_sales_monthly s
    JOIN fact_gross_price g  
        ON  g.product_code = s.product_code 
        AND g.fiscal_year = get_fiscal_year(s.date)
    WHERE FIND_IN_SET(s.customer_code, in_customer_codes) > 0
    GROUP BY s.date; 
END$$

DELIMITER ;
