-- ============================================================
-- LAYER 2 — BUSINESS METRICS
-- Goal: Answer key business questions using master_orders
-- Covers: Revenue, Geography, Sellers, Payments, Trends,
--         Delivery quality, Order status breakdown
-- Prerequisite: Run layer1_data_prep.sql first
-- ============================================================

USE olist_ecommerce;


-- ── METRIC 1: REVENUE BY PRODUCT CATEGORY ───────────────────
-- Which categories generate the most revenue?
-- Includes order count + avg review to spot high-revenue but low-quality categories

SELECT 
    product_category_name_english,
    ROUND(SUM(price + freight_value), 2) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review
FROM master_orders
WHERE product_category_name_english IS NOT NULL
GROUP BY product_category_name_english
ORDER BY total_revenue DESC;


-- ── METRIC 2: CATEGORY DEEP DIVE (example: office_furniture) ─
-- Drill into one category to benchmark its delivery + satisfaction
-- vs the overall average (see Metric 3)

SELECT 
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review,
    COUNT(DISTINCT order_id) AS total_orders
FROM master_orders
WHERE product_category_name_english = 'office_furniture';


-- ── METRIC 3: OVERALL DELIVERY + REVIEW BASELINE ────────────
-- What does a "normal" delivered order look like?
-- Use this as benchmark to compare categories, states, sellers

SELECT 
    ROUND(AVG(delivery_days), 2) AS overall_avg_delivery,
    ROUND(AVG(review_score), 2) AS overall_avg_review
FROM master_orders
WHERE order_status = 'delivered';


-- ── METRIC 4: REVENUE BY CUSTOMER STATE (TOP 10) ────────────
-- Where are our best customers geographically?
-- Only delivered orders counted — cancellations excluded from revenue

SELECT 
    customer_state,
    ROUND(SUM(price + freight_value), 2) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review
FROM master_orders
WHERE order_status = 'delivered'
GROUP BY customer_state
ORDER BY total_revenue DESC
LIMIT 10;


-- ── METRIC 5: STATE PERFORMANCE (REVENUE + DELIVERY + REVIEW) ─
-- Full picture per state: are high-revenue states also satisfied?
-- Do certain states suffer from slow delivery?

SELECT 
    customer_state,
    AVG(delivery_days) AS avg_delivery_days,
    ROUND(SUM(price + freight_value), 2) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review
FROM master_orders
WHERE order_status = 'delivered'
GROUP BY customer_state
ORDER BY total_revenue DESC
LIMIT 10;


-- ── METRIC 6: ORDER STATUS BREAKDOWN (CANCELLATION RATE) ────
-- What % of orders are delivered vs cancelled vs stuck?
-- Key health metric for the business

SELECT 
    order_status,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER() * 100, 2) AS pct_of_orders
FROM master_orders
GROUP BY order_status;


-- ── METRIC 7: SELLER PERFORMANCE BY STATE ───────────────────
-- Which seller states drive most orders and revenue?
-- Avg review + delivery per seller state reveals operational quality

SELECT
    seller_state,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(price + freight_value), 2) AS total_revenue,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days
FROM master_orders
GROUP BY seller_state
ORDER BY total_orders DESC;


-- ── METRIC 8: PAYMENT TYPE BREAKDOWN ────────────────────────
-- How do customers prefer to pay?
-- Total revenue per payment method

SELECT 
    payment_type,
    ROUND(SUM(payment_value), 2) AS total_revenue
FROM master_orders
GROUP BY payment_type;


-- ── METRIC 9: MONTHLY REVENUE TREND + MONTH-ON-MONTH GROWTH ─
-- How is revenue trending over time?
-- LAG() calculates % growth vs previous month
-- Note: 2018 data after Aug is incomplete — excluded to avoid misleading dip

WITH monthly AS (
    SELECT
        YEAR(order_purchase_timestamp)  AS year,
        MONTH(order_purchase_timestamp) AS month,
        ROUND(SUM(price + freight_value), 2) AS total_revenue
    FROM master_orders
    WHERE order_status = 'delivered'
      AND NOT (YEAR(order_purchase_timestamp) = 2018 AND MONTH(order_purchase_timestamp) >= 9)
    GROUP BY YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp)
    ORDER BY year, month
)
SELECT 
    year,
    month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY year, month) AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY year, month))
        / LAG(total_revenue) OVER (ORDER BY year, month) * 100, 2
    ) AS pct_growth
FROM monthly;


-- ── METRIC 10: DATA QUALITY CHECK (Sep-Oct 2018) ────────────
-- Verifying the 2018 cutoff decision above
-- Very low order count in Oct 2018 confirms data is incomplete

SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(price + freight_value), 2) AS total_revenue,
    YEAR(order_purchase_timestamp)  AS year,
    MONTH(order_purchase_timestamp) AS month
FROM master_orders
WHERE YEAR(order_purchase_timestamp) = 2018 
  AND MONTH(order_purchase_timestamp) = 10
GROUP BY year, month;


-- ── METRIC 11: DELIVERY SPEED vs REVIEW SCORE CORRELATION ───
-- Do faster deliveries lead to better reviews?
-- Bucketed delivery days to see the pattern clearly
-- Expected: review score drops as delivery_bucket increases

SELECT 
    CASE
        WHEN delivery_days <= 7              THEN '01 — 1 to 7 days'
        WHEN delivery_days <= 14             THEN '02 — 8 to 14 days'
        WHEN delivery_days <= 21             THEN '03 — 15 to 21 days'
        WHEN delivery_days <= 28             THEN '04 — 22 to 28 days'
        ELSE                                      '05 — 29+ days'
    END AS delivery_bucket,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(DISTINCT order_id) AS total_orders
FROM master_orders
WHERE order_status = 'delivered' 
  AND delivery_days IS NOT NULL
GROUP BY delivery_bucket
ORDER BY delivery_bucket;

SELECT 
    CASE
        WHEN delivery_days <= 7              THEN '01 — 1 to 7 days'
        WHEN delivery_days <= 14             THEN '02 — 8 to 14 days'
        WHEN delivery_days <= 21             THEN '03 — 15 to 21 days'
        WHEN delivery_days <= 28             THEN '04 — 22 to 28 days'
        ELSE                                      '05 — 29+ days'
    END AS delivery_bucket,
    customer_state,
    COUNT(order_id) as total_orders,
    ROUND(COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER(PARTITION BY customer_state), 2) as pct_of_state_total,
    ROUND(AVG(review_score), 2) as avg_review
FROM master_orders
WHERE customer_state IN ('RJ', 'RS')
GROUP BY customer_state, delivery_bucket
ORDER BY customer_state, delivery_bucket;

SELECT 
    customer_state,
    ROUND(AVG(freight_value), 2) as avg_freight,
    ROUND(AVG(price), 2) as avg_item_price,
    ROUND(AVG(freight_value) / AVG(price) * 100, 2) as freight_to_price_ratio
FROM master_orders
WHERE customer_state IN ('RJ', 'RS')
GROUP BY customer_state;

WITH CategoryStats AS (
    SELECT 
        customer_state,
        product_category_name_english, -- Note: if your master table uses the translated English names, use that column!
        COUNT(order_id) as total_orders,
        ROUND(AVG(review_score), 2) as avg_review,
        ROUND(AVG(delivery_days), 2) as avg_delivery_days
    FROM master_orders
    WHERE customer_state IN ('RJ', 'RS')
    GROUP BY customer_state, product_category_name_english
)
SELECT 
    customer_state,
    product_category_name_english,
    total_orders,
    avg_review,
    avg_delivery_days
FROM (
    SELECT*,
        ROW_NUMBER() OVER(PARTITION BY customer_state ORDER BY total_orders DESC) as rn
    FROM CategoryStats
) ranked
WHERE rn <= 10
ORDER BY customer_state, rn;

-- ============================================================
-- LAYER 2 COMPLETE
-- Output: 11 business metric queries covering revenue,
--         geography, sellers, payments, trends, delivery quality
-- Next: Layer 3 — Python RFM segmentation + deeper analysis
-- ============================================================
