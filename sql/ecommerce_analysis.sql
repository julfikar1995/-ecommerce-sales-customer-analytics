/* ============================================================
   E-COMMERCE SALES & CUSTOMER ANALYTICS
   Database: MySQL
   Author: [Your Name]
   Description: End-to-end SQL analysis of an e-commerce dataset
   covering website traffic, funnel performance, sales, and
   customer behavior. Built as a portfolio project.
   ============================================================ */


/* ============================================================
   SECTION 1: DATABASE & TABLE SETUP
   ============================================================ */

CREATE DATABASE ecommerce_sales_analysis;
USE ecommerce_sales_analysis;

CREATE TABLE website_sessions (
    website_session_id INT PRIMARY KEY,
    created_at DATETIME,
    user_id INT,
    is_repeat_session TINYINT,
    utm_source VARCHAR(50),
    utm_campaign VARCHAR(50),
    utm_content VARCHAR(50),
    device_type VARCHAR(50),
    http_referer VARCHAR(255)
);

CREATE TABLE website_pageviews (
    website_pageview_id INT PRIMARY KEY,
    created_at DATETIME,
    website_session_id INT,
    pageview_url VARCHAR(255)
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    created_at DATETIME,
    product_name VARCHAR(100)
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    created_at DATETIME,
    website_session_id INT,
    user_id INT,
    primary_product_id INT,
    items_purchased INT,
    price_usd DECIMAL(10,2),
    cogs_usd DECIMAL(10,2)
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    created_at DATETIME,
    order_id INT,
    product_id INT,
    is_primary_item TINYINT,
    price_usd DECIMAL(10,2),
    cogs_usd DECIMAL(10,2)
);

CREATE TABLE order_item_refunds (
    order_item_refund_id INT PRIMARY KEY,
    created_at DATETIME,
    order_item_id INT,
    order_id INT,
    refund_amount_usd DECIMAL(10,2)
);


/* ============================================================
   SECTION 2: DATA QUALITY CHECKS
   ============================================================ */

-- Row count sanity check across all tables
SELECT 'website_sessions' AS table_name, COUNT(*) AS row_count FROM website_sessions
UNION ALL
SELECT 'website_pageviews', COUNT(*) FROM website_pageviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_item_refunds', COUNT(*) FROM order_item_refunds;

-- Date range check
SELECT MIN(created_at) AS earliest, MAX(created_at) AS latest FROM website_sessions;
SELECT MIN(created_at) AS earliest, MAX(created_at) AS latest FROM orders;

-- NULL checks on key columns
SELECT
    SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
    SUM(CASE WHEN utm_source IS NULL THEN 1 ELSE 0 END) AS null_utm_source, -- expected: direct traffic
    SUM(CASE WHEN device_type IS NULL THEN 1 ELSE 0 END) AS null_device
FROM website_sessions;

-- Revenue/cost sanity check (no negative values)
SELECT MIN(price_usd), MAX(price_usd), MIN(cogs_usd), MAX(cogs_usd) FROM orders;


/* ============================================================
   SECTION 3: TRAFFIC & MARKETING ANALYSIS
   ============================================================ */

-- 3.1 Traffic source breakdown
SELECT
    utm_source,
    utm_campaign,
    COUNT(website_session_id) AS total_sessions
FROM website_sessions
GROUP BY utm_source, utm_campaign
ORDER BY total_sessions DESC;

-- 3.2 Monthly traffic trend
SELECT
    YEAR(created_at) AS yr,
    MONTH(created_at) AS mo,
    COUNT(website_session_id) AS total_sessions
FROM website_sessions
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY yr, mo;

-- 3.3 Device type breakdown
SELECT
    device_type,
    COUNT(website_session_id) AS total_sessions,
    ROUND(COUNT(website_session_id) * 100.0 / (SELECT COUNT(*) FROM website_sessions), 2) AS pct_of_total
FROM website_sessions
GROUP BY device_type
ORDER BY total_sessions DESC;


/* ============================================================
   SECTION 4: WEBSITE FUNNEL ANALYSIS
   ============================================================ */

-- 4.1 Overall session-to-order conversion rate
SELECT
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT ws.website_session_id), 2) AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id;

-- 4.2 Conversion rate by device type
SELECT
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT ws.website_session_id), 2) AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY ws.device_type
ORDER BY conversion_rate_pct DESC;

-- 4.3 Page-by-page funnel drop-off
SELECT DISTINCT pageview_url
FROM website_pageviews
ORDER BY pageview_url;

SELECT
    COUNT(DISTINCT CASE WHEN pageview_url = '/home' OR pageview_url LIKE '/lander-%' THEN website_session_id END) AS landing_page,
    COUNT(DISTINCT CASE WHEN pageview_url = '/products' THEN website_session_id END) AS products_page,
    COUNT(DISTINCT CASE WHEN pageview_url = '/cart' THEN website_session_id END) AS cart_page,
    COUNT(DISTINCT CASE WHEN pageview_url = '/shipping' THEN website_session_id END) AS shipping_page,
    COUNT(DISTINCT CASE WHEN pageview_url IN ('/billing', '/billing-2') THEN website_session_id END) AS billing_page,
    COUNT(DISTINCT CASE WHEN pageview_url = '/thank-you-for-your-order' THEN website_session_id END) AS thankyou_page
FROM website_pageviews;


/* ============================================================
   SECTION 5: SALES & REVENUE ANALYSIS
   ============================================================ */

-- 5.1 Overall revenue & key sales metrics
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(price_usd) AS total_revenue,
    ROUND(AVG(price_usd), 2) AS avg_order_value,
    SUM(price_usd) - SUM(cogs_usd) AS total_profit,
    ROUND((SUM(price_usd) - SUM(cogs_usd)) * 100.0 / SUM(price_usd), 2) AS profit_margin_pct
FROM orders;

-- 5.2 Monthly revenue trend
SELECT
    YEAR(created_at) AS yr,
    MONTH(created_at) AS mo,
    COUNT(order_id) AS num_orders,
    SUM(price_usd) AS monthly_revenue
FROM orders
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY yr, mo;

-- 5.3 Product-wise performance
SELECT
    p.product_name,
    COUNT(oi.order_item_id) AS units_sold,
    SUM(oi.price_usd) AS total_revenue,
    ROUND(AVG(oi.price_usd), 2) AS avg_price,
    SUM(oi.price_usd) - SUM(oi.cogs_usd) AS total_profit
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC;

-- 5.4 Refund analysis by product
SELECT
    p.product_name,
    COUNT(DISTINCT oi.order_item_id) AS total_items_sold,
    COUNT(DISTINCT oir.order_item_id) AS total_items_refunded,
    ROUND(COUNT(DISTINCT oir.order_item_id) * 100.0 / COUNT(DISTINCT oi.order_item_id), 2) AS refund_rate_pct,
    SUM(oir.refund_amount_usd) AS total_refund_amount
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
GROUP BY p.product_name
ORDER BY refund_rate_pct DESC;


/* ============================================================
   SECTION 6: CUSTOMER ANALYSIS
   ============================================================ */

-- 6.1 New vs repeat customers
SELECT
    order_count,
    COUNT(user_id) AS num_customers
FROM (
    SELECT user_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY user_id
) AS customer_orders
GROUP BY order_count
ORDER BY order_count;

-- 6.2 Average days between first and second purchase
SELECT
    ROUND(AVG(DATEDIFF(second_order.created_at, first_order.created_at)), 1) AS avg_days_between_orders
FROM (
    SELECT user_id, MIN(created_at) AS created_at
    FROM orders
    GROUP BY user_id
) AS first_order
JOIN (
    SELECT o.user_id, MIN(o.created_at) AS created_at
    FROM orders o
    JOIN (
        SELECT user_id, MIN(created_at) AS first_date
        FROM orders
        GROUP BY user_id
    ) fo ON o.user_id = fo.user_id AND o.created_at > fo.first_date
    GROUP BY o.user_id
) AS second_order
ON first_order.user_id = second_order.user_id;

-- 6.3 Top 10 customers by revenue
SELECT
    user_id,
    COUNT(order_id) AS total_orders,
    SUM(price_usd) AS total_spent
FROM orders
GROUP BY user_id
ORDER BY total_spent DESC
LIMIT 10;


/* ============================================================
   SECTION 7: VIEWS FOR POWER BI
   ============================================================ */

-- 7.1 Monthly trends
CREATE VIEW vw_monthly_trends AS
SELECT
    YEAR(ws.created_at) AS yr,
    MONTH(ws.created_at) AS mo,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(o.price_usd), 2) AS total_revenue,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT ws.website_session_id), 2) AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY YEAR(ws.created_at), MONTH(ws.created_at)
ORDER BY yr, mo;

-- 7.2 Traffic source performance
CREATE VIEW vw_traffic_source_performance AS
SELECT
    COALESCE(ws.utm_source, 'direct') AS traffic_source,
    COALESCE(ws.utm_campaign, 'none') AS campaign,
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(o.price_usd), 2) AS total_revenue,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT ws.website_session_id), 2) AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY COALESCE(ws.utm_source, 'direct'), COALESCE(ws.utm_campaign, 'none'), ws.device_type;

-- 7.3 Product performance
CREATE VIEW vw_product_performance AS
SELECT
    p.product_name,
    COUNT(DISTINCT oi.order_item_id) AS units_sold,
    ROUND(SUM(oi.price_usd), 2) AS total_revenue,
    ROUND(SUM(oi.price_usd) - SUM(oi.cogs_usd), 2) AS total_profit,
    ROUND((SUM(oi.price_usd) - SUM(oi.cogs_usd)) * 100.0 / SUM(oi.price_usd), 2) AS profit_margin_pct,
    COUNT(DISTINCT oir.order_item_id) AS units_refunded,
    ROUND(COUNT(DISTINCT oir.order_item_id) * 100.0 / COUNT(DISTINCT oi.order_item_id), 2) AS refund_rate_pct
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
GROUP BY p.product_name;

-- 7.4 Customer behavior (new vs repeat)
CREATE VIEW vw_customer_behavior AS
SELECT
    order_count,
    COUNT(user_id) AS num_customers,
    ROUND(COUNT(user_id) * 100.0 / (SELECT COUNT(DISTINCT user_id) FROM orders), 2) AS pct_of_customers
FROM (
    SELECT user_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY user_id
) AS customer_orders
GROUP BY order_count;

-- 7.5 Website funnel (page-level drop-off)
CREATE VIEW vw_website_funnel AS
SELECT
    COUNT(DISTINCT CASE WHEN pageview_url = '/home' OR pageview_url LIKE '/lander-%' THEN website_session_id END) AS landing_page,
    COUNT(DISTINCT CASE WHEN pageview_url = '/products' THEN website_session_id END) AS products_page,
    COUNT(DISTINCT CASE WHEN pageview_url = '/cart' THEN website_session_id END) AS cart_page,
    COUNT(DISTINCT CASE WHEN pageview_url = '/shipping' THEN website_session_id END) AS shipping_page,
    COUNT(DISTINCT CASE WHEN pageview_url IN ('/billing', '/billing-2') THEN website_session_id END) AS billing_page,
    COUNT(DISTINCT CASE WHEN pageview_url = '/thank-you-for-your-order' THEN website_session_id END) AS thankyou_page
FROM website_pageviews;

-- 7.6 Device-wise conversion summary
CREATE VIEW vw_device_conversion AS
SELECT
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(o.price_usd), 2) AS total_revenue,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT ws.website_session_id), 2) AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY ws.device_type;
