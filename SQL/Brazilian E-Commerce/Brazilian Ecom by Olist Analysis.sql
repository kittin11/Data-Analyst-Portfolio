-- Exploratory Data Analysis (EDA)

-- Customers
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'customers';

SELECT COUNT(customer_id) AS non_null_customer_id,
	COUNT(customer_unique_id) AS non_null_customer_unique,
	COUNT(customer_zip_code_prefix) AS non_null_customer_zip_code,
	COUNT(customer_city) AS non_null_customer_city,
	COUNT(customer_state) AS non_null_customer_state,
	COUNT(*) AS total_rows
FROM customers;

SELECT customer_id, COUNT(*) AS duplicate_count
FROM customers
GROUP BY customer_id
ORDER BY duplicate_count DESC;

-- Order Items
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'order_items';

SELECT 
	COUNT(order_id) AS non_null_order_id,
	COUNT(order_item_id) AS non_null_order_item_id,
	COUNT(product_id) AS non_null_product_id,
	COUNT(seller_id) AS non_null_seller_id,
	COUNT(shipping_limit_date) AS non_null_shipping_limit_date,
	COUNT(price) AS non_null_price,
	COUNT(freight_value) AS non_null_freight_value,
	COUNT(*) AS total_rows,
	MIN(price) AS min_price,
	MAX(price) AS max_price,
	ROUND(AVG(price::NUMERIC), 2) AS mean_price,
	ROUND(STDDEV(price::NUMERIC), 2) AS sd_price,
	MIN(freight_value) AS min_frieght,
	MAX(freight_value) AS max_frieght,
	ROUND(AVG(freight_value::NUMERIC), 2) AS mean_frieght,
	ROUND(STDDEV(freight_value::NUMERIC), 2) AS sd_frieght
FROM order_items;

-- Orders
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'orders'

SELECT 
	order_status,
	COUNT(*) AS total_order_status
FROM orders
GROUP BY order_status
ORDER BY total_order_status DESC;
	

SELECT 
	COUNT(order_id) AS non_null_order_id,
	COUNT(customer_id) AS non_null_customer_id,
	COUNT(order_status) AS non_null_order_status
FROM orders;

SELECT
	order_id,
	COUNT(*) AS duplicate_order
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT
	customer_id,
	COUNT(*) AS duplicate_customer
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- products
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'products';

SELECT product_category_name
FROM products
GROUP BY product_category_name
ORDER BY product_category_name ASC;

SELECT COUNT(product_category_name) AS non_null_product_category_name,
	COUNT(*),
	COUNT(*) - COUNT(product_category_name) AS missing
FROM products

SELECT *
FROM products
WHERE product_category_name IS NULL;

-- product translation
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'product_categories';

SELECT TRIM(product_category_name_english)
FROM product_categories;

SELECT product_category_name_english
FROM product_categories
GROUP BY product_category_name_english;

-- Order reviews
SELECT 
	COUNT(review_id),
	COUNT(order_id),
	COUNT(*)
FROM order_reviews;

SELECT 
	MAX(review_score),
	MIN(review_score),
	AVG(review_score)
FROM order_reviews

----------------------------------------------------------------------------------

-- Data Exploration

-- Which month had the highest sales and what was the sales growth that month?

WITH total_revenue_by_month AS (
	SELECT EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
		ROUND(SUM(o_i.price::NUMERIC), 2) AS total_revenue
	FROM orders o
		INNER JOIN order_items AS o_i
		USING(order_id)
	WHERE o.order_status IN ('delivered', 'shipped', 'invoiced', 'processing', 'approved')
	GROUP BY month
	ORDER BY month ASC
),
total_revenue_before_mom AS (
	SELECT month,
		total_revenue,
		LAG(total_revenue, 1) OVER(ORDER BY month) AS prior_revenue
	FROM total_revenue_by_month
)
SELECT month,
	total_revenue,
	prior_revenue,
	((total_revenue / prior_revenue) - 1) * 100 AS MoM
FROM total_revenue_before_mom;

-- The month with the highest income was the 5th month.
-- But the highest sales growth was in November at 42.45%.
-- September has the highest sales decline at -56.12% from the previous month.

----------------------------------------------------------------------------------

-- Top 10 best selling products categories

SELECT 
	p.product_category_name,
	COUNT(o.order_id) AS total_order,
	ROW_NUMBER() OVER(ORDER BY COUNT(o.order_id ) DESC) AS ranking
FROM orders o
	INNER JOIN order_items o_i
	USING(order_id)
	INNER JOIN products p
	USING(product_id)
WHERE p.product_category_name IS NOT NULL
GROUP BY product_category_name
ORDER BY total_order DESC
LIMIT 10;

-- The product with the most orders is cama_mesa_banho with 11115 orders.

----------------------------------------------------------------------------------

-- Average review score for each product category
SELECT product_category_name,
	ROUND(AVG(o_r.review_score), 2) AS average_review_score, 
	ROUND(AVG(EXTRACT(DAY FROM order_delivered_customer_date - order_delivered_carrier_date)), 0) AS avg_day_delivery_to_customer
FROM orders AS o
	INNER JOIN order_items AS o_i
		USING(order_id)
	INNER JOIN products AS p
		USING(product_id)
	INNER JOIN order_reviews AS o_r
		USING(order_id)
GROUP BY product_category_name
ORDER BY average_review_score ASC;

-- The lowest average review score is seguros_e_servicos with 2.50. This may be due to the fact that the average delivery time for this product type is 13 days, which is considered the longest.

----------------------------------------------------------------------------------

-- Popular payment channels
WITH total_use_payment AS(
	SELECT 
		op.payment_type,
		COUNT(o.order_id) AS use_payment
	FROM orders AS o
		INNER JOIN order_payments AS op
			ON o.order_id = op.order_id
	GROUP BY payment_type
)
SELECT payment_type,
	use_payment,
	ROUND(100::DECIMAL * use_payment / (SELECT 
											COUNT(order_id) 
										 FROM orders), 3) AS rate_use_payment
FROM total_use_payment
ORDER BY rate_use_payment DESC

-- Credit_card is the most popular payment method, at 77.23 %.

----------------------------------------------------------------------------------

-- Create a view to capture the total number of orders and revenue, including calculating cumulative revenue.
CREATE VIEW summarize_by_state AS 
WITH detail_by_state AS (
SELECT 
	geo.geolocation_state AS state,
	COUNT(o.order_id) AS total_order,
	ROUND(SUM(payment_value)::NUMERIC,0) AS revenue_by_state
FROM orders AS o
	INNER JOIN order_payments AS op
		USING(order_id)
	INNER JOIN customers AS cus
		USING(customer_id)
	INNER JOIN geo_location AS geo
		ON cus.customer_zip_code_prefix = geo.geolocation_zip_code_prefix
WHERE o.order_status IN ('delivered', 'shipped', 'invoiced', 'processing', 'approved')
GROUP BY geo.geolocation_state
) 
SELECT 
	state,
    total_order,
    revenue_by_state,
    SUM(revenue_by_state) OVER (ORDER BY state ROWS UNBOUNDED PRECEDING) AS cumulative_revenue
FROM detail_by_state;