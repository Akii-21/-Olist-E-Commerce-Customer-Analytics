-- ============================================================
-- LAYER 1 — DATA PREPARATION & MASTER TABLE
-- Goal: Explore raw data, add indexes, build single source
--       of truth (master_orders) for all analysis above
-- ============================================================


-- ── DATABASE SETUP ──────────────────────────────────────────
CREATE DATABASE olist_ecommerce;
USE olist_ecommerce;


-- ── STEP 1: RAW DATA EXPLORATION ────────────────────────────
-- Quick peek at all 9 tables to understand structure

SELECT * FROM orders;

-- Count orders by status + percentage share
SELECT 
    order_status,
    COUNT(*) AS Total_orders,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER() * 100, 2) AS pct_of_orders
FROM orders
GROUP BY order_status;

-- Check date range of the dataset (2016–2018?)
SELECT 
    MAX(order_purchase_timestamp) AS Last_order,
    MIN(order_purchase_timestamp) AS First_order
FROM orders;

-- Count how many orders were never delivered (NULL delivery date)
SELECT 
    COUNT(*) AS Total_order,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS Missing_orders
FROM orders;

-- Preview all supporting tables
SELECT * FROM order_items LIMIT 5;
SELECT * FROM order_payments LIMIT 5;
SELECT * FROM order_reviews LIMIT 5;
SELECT * FROM customers LIMIT 5;
SELECT * FROM products LIMIT 5;
SELECT * FROM category_translation LIMIT 5;

-- Check all unique order statuses in the dataset
SELECT DISTINCT(order_status) FROM orders LIMIT 5;


-- ── STEP 2: ADD INDEXES ON JOIN KEYS ────────────────────────
-- Speeds up all JOIN queries significantly on 100k+ rows
-- Without this, MySQL does full table scans on every join

ALTER TABLE sellers      ADD INDEX idx_seller_id   (seller_id(50));
ALTER TABLE orders       ADD INDEX idx_order_id    (order_id(50));
ALTER TABLE order_items  ADD INDEX idx_order_id    (order_id(50));
ALTER TABLE order_payments ADD INDEX idx_order_id  (order_id(50));
ALTER TABLE order_reviews  ADD INDEX idx_order_id  (order_id(50));
ALTER TABLE customers    ADD INDEX idx_customer_id (customer_id(50));
ALTER TABLE products     ADD INDEX idx_product_id  (product_id(50));


-- ── STEP 3: CREATE MASTER VIEW (lightweight test version) ───
-- Joins all 9 tables into one flat view
-- Note: view is slow on large data — used only for validation
-- Final analysis uses master_orders TABLE below

CREATE VIEW vw_orders_master AS
SELECT 
    o.order_id, o.customer_id, o.order_status, o.order_purchase_timestamp, 
    o.order_approved_at, o.order_delivered_carrier_date, 
    o.order_delivered_customer_date, o.order_estimated_delivery_date,  -- from orders

    oi.price, COALESCE(oi.freight_value, 0) AS freight_value,           -- from order_items
    op.payment_type, COALESCE(op.payment_value, 0) AS payment_value,    -- from order_payments
    r.review_score,                                                       -- from order_reviews (NULL kept intentionally)
    c.customer_city, c.customer_state,                                   -- from customers
    ct.product_category_name_english,                                    -- from products + category_translation
    s.seller_state,                                                       -- from sellers

    -- Delivery duration in days (NULL if data is logically impossible)
    CASE 
        WHEN o.order_delivered_customer_date < o.order_purchase_timestamp THEN NULL
        ELSE DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) 
    END AS delivery_days,

    -- Order status flags for easy filtering/aggregation later
    CASE WHEN o.order_status = 'delivered'    THEN 1 ELSE 0 END AS is_delivered,
    CASE WHEN o.order_status = 'invoiced'     THEN 1 ELSE 0 END AS is_invoiced,
    CASE WHEN o.order_status = 'shipped'      THEN 1 ELSE 0 END AS is_shipped,
    CASE WHEN o.order_status = 'processing'   THEN 1 ELSE 0 END AS is_processing,
    CASE WHEN o.order_status = 'unavailable'  THEN 1 ELSE 0 END AS is_unavailable

FROM orders o
LEFT JOIN (
    -- Aggregate order_items to order level to avoid row multiplication
    -- Without this, one order with 3 items would create 3 rows, inflating revenue 3x
    SELECT order_id, MAX(product_id) AS product_id, MAX(seller_id) AS seller_id,
           SUM(price) AS price, SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
) oi ON oi.order_id = o.order_id
LEFT JOIN (
    -- Aggregate payments to order level (orders can have multiple payment methods)
    SELECT order_id, SUM(payment_value) AS payment_value, MAX(payment_type) AS payment_type 
    FROM order_payments
    GROUP BY order_id
) op ON op.order_id = o.order_id
LEFT JOIN order_reviews  r  ON r.order_id  = o.order_id
LEFT JOIN customers      c  ON c.customer_id = o.customer_id
LEFT JOIN products       p  ON p.product_id = oi.product_id
LEFT JOIN category_translation ct ON ct.product_category_name = p.product_category_name
LEFT JOIN sellers        s  ON s.seller_id  = oi.seller_id;

-- Validate view looks correct
SELECT * FROM vw_orders_master LIMIT 10;


-- ── STEP 4: CREATE MASTER TABLE (permanent, fast) ───────────
-- Materializing the view as a TABLE for performance
-- All Layer 2 queries run against this table

CREATE TABLE master_orders AS
SELECT 
    o.order_id, o.customer_id, o.order_status, o.order_purchase_timestamp, 
    o.order_approved_at, o.order_delivered_carrier_date, 
    o.order_delivered_customer_date, o.order_estimated_delivery_date,
    oi.price, COALESCE(oi.freight_value, 0) AS freight_value,
    op.payment_type, COALESCE(op.payment_value, 0) AS payment_value,
    COALESCE(r.review_score, 3) AS review_score,  -- NULL reviews defaulted to 3 (neutral)
    c.customer_city, c.customer_state,
    ct.product_category_name_english,
    s.seller_state,
    CASE 
        WHEN o.order_delivered_customer_date < o.order_purchase_timestamp THEN NULL
        ELSE DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) 
    END AS delivery_days,
    CASE WHEN o.order_status = 'delivered'   THEN 1 ELSE 0 END AS is_delivered,
    CASE WHEN o.order_status = 'invoiced'    THEN 1 ELSE 0 END AS is_invoiced,
    CASE WHEN o.order_status = 'shipped'     THEN 1 ELSE 0 END AS is_shipped,
    CASE WHEN o.order_status = 'processing'  THEN 1 ELSE 0 END AS is_processing,
    CASE WHEN o.order_status = 'unavailable' THEN 1 ELSE 0 END AS is_unavailable
FROM orders o
LEFT JOIN (
    SELECT order_id, MAX(product_id) AS product_id, MAX(seller_id) AS seller_id,
           SUM(price) AS price, SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
) oi ON oi.order_id = o.order_id
LEFT JOIN (
    SELECT order_id, SUM(payment_value) AS payment_value, MAX(payment_type) AS payment_type 
    FROM order_payments
    GROUP BY order_id
) op ON op.order_id = o.order_id
LEFT JOIN order_reviews r ON r.order_id = o.order_id
LEFT JOIN customers     c ON c.customer_id = o.customer_id
LEFT JOIN products      p ON p.product_id = oi.product_id
LEFT JOIN category_translation ct ON ct.product_category_name = p.product_category_name
LEFT JOIN sellers       s ON s.seller_id = oi.seller_id;

-- Validate master table
SELECT * FROM master_orders LIMIT 5;


-- ── STEP 5: DATA QUALITY FIX ─────────────────────────────────
-- Replace NULL seller_state with 'Unknown' for cleaner grouping
-- NULL rows would silently disappear in GROUP BY queries

SET SQL_SAFE_UPDATES = 0;
UPDATE master_orders 
SET seller_state = 'Unknown'
WHERE seller_state IS NULL;
SET SQL_SAFE_UPDATES = 1;

-- ============================================================
-- LAYER 1 COMPLETE
-- Output: master_orders table — clean, joined, ready for analysis
-- ============================================================
