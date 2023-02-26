SELECT * FROM dim_customer;
SELECT * FROM dim_product;
SELECT * FROM fact_gross_price;
SELECT * FROM fact_manufacturing_cost;
SELECT * FROM fact_pre_invoice_deductions;
SELECT * FROM fact_sales_monthly;


/* 1) The list of markets in which customer  "Atliq  Exclusive"  operates its  
business in the  APAC  region. */ 
SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive'
	  AND region = 'APAC';

# 2) Percentage of Unique product Increase in 2021 from 2020
WITH products2020 AS 
(
	SELECT COUNT(DISTINCT product_code) AS unique_products2020 
    FROM fact_sales_monthly
	WHERE fiscal_year = 2020
),
products2021 AS 
(
	SELECT COUNT(DISTINCT product_code) AS unique_products2021 
    FROM fact_sales_monthly
	WHERE fiscal_year = 2021
)
SELECT unique_products2020, 
	   unique_products2021, 
       ROUND(((unique_products2021/unique_products2020)-1)*100,2) AS percentage_chg
FROM products2020
CROSS JOIN products2021;

/* 3) All the unique product counts for each  segment, sorted in descending order
 of product counts. */
 SELECT segment, COUNT(DISTINCT product_code) AS product_count FROM dim_product
 GROUP BY segment
 ORDER BY product_count DESC;
 
  
  # 4) Which segment had the most increase in unique products in 2021 vs 2020
WITH base_table AS
(
	SELECT segment, fact_sales_monthly.product_code, product, sold_quantity, fiscal_year
    FROM fact_sales_monthly
    LEFT JOIN dim_product
    ON fact_sales_monthly.product_code = dim_product.product_code
 ),
products2020 AS 
(
	SELECT segment, COUNT(DISTINCT product_code) AS quantity2020 
    FROM base_table
	WHERE fiscal_year = 2020
    GROUP BY segment
),
products2021 AS 
(
	SELECT segment, COUNT(DISTINCT product_code) AS quantity2021 
    FROM base_table
	WHERE fiscal_year = 2021
	GROUP BY segment
)
SELECT products2020.segment,
	   quantity2020, 
	   quantity2021, 
       quantity2021-quantity2020 AS difference
FROM products2020
INNER JOIN products2021 ON products2020.segment = products2021.segment
ORDER BY difference DESC;
# Accessories Segment had the most increase in unique products


# 5) Products that have the highest and lowest manufacturing costs.
WITH min_max_product AS
(
	SELECT product_code, manufacturing_cost 
    FROM fact_manufacturing_cost
	WHERE manufacturing_cost = 
							(
							SELECT MAX(manufacturing_cost) 
							FROM fact_manufacturing_cost
							)
	UNION
	SELECT product_code, 
		   manufacturing_cost 
	FROM fact_manufacturing_cost
	WHERE manufacturing_cost = 
							(
                            SELECT MIN(manufacturing_cost) 
                            FROM fact_manufacturing_cost
                            )
)
SELECT min_max_product.product_code, 
	   product, manufacturing_cost 
FROM min_max_product
INNER JOIN dim_product
ON dim_product.product_code = min_max_product.product_code;
/* AQ Master wiredx1 has the lowest manufacturing cost where as 
AQ HOME Allin1 Gen2 has the highest manufacturing cost */


/* 6) Top 5 customers who received an  average high  pre_invoice_discount_pct  for 
the fiscal year 2021 and in the Indian market */
WITH customer_discount_table AS 
	(
    SELECT dim_customer.customer_code, 
		   customer, 
           market, 
           fiscal_year, 
           pre_invoice_discount_pct
	FROM fact_pre_invoice_deductions
	INNER JOIN dim_customer
	ON fact_pre_invoice_deductions.customer_code = dim_customer.customer_code
	WHERE fiscal_year = 2021 
		  AND market = "India"
)
SELECT customer_code, 
	   customer, 
       ROUND(AVG(pre_invoice_discount_pct),2) AS average_discount_percentage
FROM customer_discount_table
GROUP BY customer_code
ORDER BY average_discount_percentage DESC
LIMIT 5;

/* 7) Complete report of the Gross sales amount for the customer 
“Atliq  Exclusive” for each month */
WITH joined_table AS 
	(
    SELECT date, 
		   month(date) AS month, 
           year(date) AS year, 
           customer, 
           fact_sales_monthly.fiscal_year, 
           sold_quantity, gross_price, 
           ROUND(sold_quantity*gross_price,2) AS sales_amount 
	FROM fact_sales_monthly
	LEFT JOIN dim_customer
	ON fact_sales_monthly.customer_code = dim_customer.customer_code
	LEFT JOIN fact_gross_price
	ON fact_sales_monthly.product_code = fact_gross_price.product_code 
	   AND fact_sales_monthly.fiscal_year = fact_gross_price.fiscal_year
	WHERE customer = 'Atliq Exclusive'
	)
SELECT month,
	   IF(month>=9,2020,2021) AS year,
	   SUM(sales_amount)
FROM joined_table
GROUP BY month;


# 8) Quarter of 2020 with the maximum total_sold_quantity
SELECT 
	CASE 
	WHEN month(date) IN (9,10,11) THEN 'Q1'
	WHEN month(date) IN (12,1,2) THEN 'Q2'
	WHEN month(date) IN (3,4,5) THEN 'Q3' 
	WHEN month(date) IN (6,7,8) THEN 'Q4'
	END AS quarter,
	SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
GROUP BY quarter
ORDER BY total_sold_quantity DESC;

/* 9) Channel that helped to bring more gross sales in the fiscal year 2021  and
 the percentage of contribution */
 WITH combined_table AS 
 (SELECT channel, fact_sales_monthly.fiscal_year, 
           sold_quantity, gross_price, 
           ROUND(sold_quantity*gross_price,2) AS sales_amount 
	FROM fact_sales_monthly
	LEFT JOIN dim_customer
	ON fact_sales_monthly.customer_code = dim_customer.customer_code
	LEFT JOIN fact_gross_price
	ON fact_sales_monthly.product_code = fact_gross_price.product_code 
	   AND fact_sales_monthly.fiscal_year = fact_gross_price.fiscal_year
	WHERE fact_sales_monthly.fiscal_year = 2020),
    channel_contribution_table AS (SELECT channel, SUM(sales_amount) AS gross_sales
    FROM combined_table
    GROUP BY channel
    ORDER BY gross_sales DESC)
SELECT channel, 
	   gross_sales, 
	   100*gross_sales/SUM(gross_sales) OVER() AS percentage
FROM channel_contribution_table;
    
    
/* 10) Top 3 products in each division that have a high total_sold_quantity 
in the fiscal_year 2021 */
WITH product_rank_table AS 
	(
     SELECT division,
			fact_sales_monthly.product_code, 
			product, 
			SUM(sold_quantity) AS total_sold_quantity,
			RANK() OVER(PARTITION BY division ORDER BY SUM(sold_quantity) DESC) AS rank_order
	 FROM fact_sales_monthly
	 INNER JOIN dim_product
	 ON fact_sales_monthly.product_code = dim_product.product_code
	 WHERE fiscal_year = 2021
	 GROUP BY division, product_code, product
     )
SELECT division,
	   product_rank_table.product_code, 
	   product,
	   total_sold_quantity,
	   rank_order
FROM product_rank_table
WHERE rank_order IN (1,2,3);