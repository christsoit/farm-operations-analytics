-- =========================================================================
-- Yong Sheng Operations Analytics — KPI Queries
-- =========================================================================
-- Author:  Chris Tsoi
--
-- Powers the Tableau operational dashboard. All queries designed to run
-- against the cleaned analytics layer (orders_cleaned, order_items, 
-- deliveries) rather than raw intake.
--
-- Query index:
--   PART 1: Volume & Revenue Overview  (queries 1-3)
--   PART 2: Fulfillment & Delivery     (queries 4-7)
--   PART 3: Customer Analytics          (queries 8-10)
--   PART 4: Product & Inventory         (queries 11-13)
-- =========================================================================


-- =========================================================================
-- PART 1: VOLUME & REVENUE OVERVIEW
-- Top-level operational KPIs for the dashboard header
-- =========================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- Query 1: Total Order Volume
-- Total cleaned orders in the analysis window
-- ─────────────────────────────────────────────────────────────────────────
SELECT COUNT(*) AS total_orders
FROM orders_cleaned;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 2: Total Confirmed Revenue
-- Revenue from confirmed items × unit price (excludes pending)
-- ─────────────────────────────────────────────────────────────────────────
SELECT 
    SUM(COALESCE(oi.confirmed_quantity, 0) * oi.unit_price) AS total_revenue
FROM order_items oi;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 3: Weekly Order Trend
-- DATE_TRUNC groups by ISO week for time-series charts
-- ─────────────────────────────────────────────────────────────────────────
SELECT 
    DATE_TRUNC('week', order_date)::date AS week_start,
    COUNT(*) AS orders,
    SUM(COALESCE(total_value, 0)) AS weekly_revenue
FROM orders_cleaned
GROUP BY DATE_TRUNC('week', order_date)
ORDER BY week_start;


-- =========================================================================
-- PART 2: FULFILLMENT & DELIVERY
-- Operational KPIs measuring performance against demand
-- =========================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- Query 4: Overall Fill Rate
-- % of requested quantity that was confirmed
-- ─────────────────────────────────────────────────────────────────────────
SELECT 
    ROUND(
        SUM(COALESCE(confirmed_quantity, 0)) * 100.0 / NULLIF(SUM(requested_quantity), 0),
        2
    ) AS overall_fill_rate_pct
FROM order_items;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 5: Weekly Fill Rate with 4-Week Rolling Average
-- CTE isolates weekly aggregation; window function smooths noise
-- ─────────────────────────────────────────────────────────────────────────
WITH weekly_fill AS (
    SELECT 
        DATE_TRUNC('week', o.order_date)::date AS week_start,
        SUM(oi.requested_quantity) AS requested,
        SUM(COALESCE(oi.confirmed_quantity, 0)) AS confirmed
    FROM orders_cleaned o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY DATE_TRUNC('week', o.order_date)
)
SELECT 
    week_start,
    ROUND(confirmed * 100.0 / NULLIF(requested, 0), 2) AS weekly_fill_rate,
    ROUND(
        AVG(confirmed * 100.0 / NULLIF(requested, 0)) 
            OVER (ORDER BY week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW),
        2
    ) AS rolling_4wk_avg
FROM weekly_fill
ORDER BY week_start;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 6: Daily On-Time Delivery Rate with 7-Day Rolling %
-- Combines conditional aggregation with rolling window
-- ─────────────────────────────────────────────────────────────────────────
WITH daily_delivery AS (
    SELECT 
        DATE(scheduled_delivery_time) AS delivery_date,
        COUNT(*) AS total,
        SUM(CASE 
            WHEN delivery_status = 'delivered' 
             AND DATE(actual_delivery_time) = DATE(scheduled_delivery_time) 
            THEN 1 
            ELSE 0 
        END) AS on_time
    FROM deliveries
    GROUP BY DATE(scheduled_delivery_time)
)
SELECT 
    delivery_date,
    total,
    on_time,
    ROUND(on_time * 100.0 / NULLIF(total, 0), 1) AS on_time_pct,
    ROUND(
        SUM(on_time) OVER (ORDER BY delivery_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) * 100.0
        / NULLIF(SUM(total) OVER (ORDER BY delivery_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0),
        1
    ) AS rolling_7day_on_time_pct
FROM daily_delivery
ORDER BY delivery_date;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 7: Driver Productivity Ranking
-- CTE + RANK() to identify top-performing drivers
-- ─────────────────────────────────────────────────────────────────────────
WITH driver_stats AS (
    SELECT 
        w.worker_id,
        w.worker_name,
        w.role,
        COUNT(*) AS total_deliveries,
        SUM(CASE 
            WHEN d.delivery_status = 'delivered' 
             AND DATE(d.actual_delivery_time) = DATE(d.scheduled_delivery_time) 
            THEN 1 
            ELSE 0 
        END) AS on_time
    FROM deliveries d
    JOIN workers w ON d.driver_worker_id = w.worker_id
    GROUP BY w.worker_id, w.worker_name, w.role
)
SELECT 
    worker_name,
    role,
    total_deliveries,
    ROUND(on_time * 100.0 / NULLIF(total_deliveries, 0), 1) AS on_time_pct,
    RANK() OVER (ORDER BY total_deliveries DESC) AS volume_rank
FROM driver_stats
ORDER BY total_deliveries DESC;


-- =========================================================================
-- PART 3: CUSTOMER ANALYTICS
-- Understanding who buys what and how much
-- =========================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- Query 8: Top Customers by Revenue with Market-Type Ranking
-- Global rank + partitioned rank within market_type
-- ─────────────────────────────────────────────────────────────────────────
WITH customer_revenue AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.market_type,
        SUM(COALESCE(oi.confirmed_quantity, 0) * oi.unit_price) AS revenue,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders_cleaned o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.market_type
)
SELECT 
    customer_name,
    market_type,
    order_count,
    ROUND(revenue, 2) AS total_revenue,
    RANK() OVER (ORDER BY revenue DESC) AS overall_rank,
    RANK() OVER (PARTITION BY market_type ORDER BY revenue DESC) AS rank_within_market
FROM customer_revenue
ORDER BY revenue DESC
LIMIT 15;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 9: Customer Quartile Segmentation (Pareto Analysis)
-- NTILE(4) buckets customers for 80/20 concentration analysis
-- ─────────────────────────────────────────────────────────────────────────
WITH customer_revenue AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.market_type,
        SUM(COALESCE(oi.confirmed_quantity, 0) * oi.unit_price) AS revenue
    FROM orders_cleaned o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.market_type
)
SELECT 
    customer_name,
    market_type,
    ROUND(revenue, 2) AS revenue,
    NTILE(4) OVER (ORDER BY revenue DESC) AS revenue_quartile,
    CASE NTILE(4) OVER (ORDER BY revenue DESC)
        WHEN 1 THEN 'Top 25% (Whales)'
        WHEN 2 THEN 'Upper mid'
        WHEN 3 THEN 'Lower mid'
        WHEN 4 THEN 'Bottom 25% (Long tail)'
    END AS segment
FROM customer_revenue
ORDER BY revenue DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 10: Revenue by Market Type
-- Aggregates buyer segments for strategic planning
-- ─────────────────────────────────────────────────────────────────────────
SELECT 
    c.market_type,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(SUM(COALESCE(oi.confirmed_quantity, 0) * oi.unit_price), 2) AS revenue,
    ROUND(SUM(COALESCE(oi.confirmed_quantity, 0) * oi.unit_price) * 100.0 
        / (SELECT SUM(COALESCE(confirmed_quantity, 0) * unit_price) FROM order_items), 1
    ) AS pct_of_total_revenue
FROM customers c
JOIN orders_cleaned o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.market_type
ORDER BY revenue DESC;


-- =========================================================================
-- PART 4: PRODUCT & INVENTORY
-- What sells, what's short, what's overstocked
-- =========================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- Query 11: Top Products by Demand and Shortage
-- Combined view: what's popular AND what's under-stocked
-- ─────────────────────────────────────────────────────────────────────────
WITH product_stats AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.requested_quantity) AS total_requested,
        SUM(COALESCE(oi.confirmed_quantity, 0)) AS total_confirmed,
        SUM(oi.requested_quantity - COALESCE(oi.confirmed_quantity, 0)) AS shortage
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.product_name, p.category
)
SELECT 
    product_name,
    category,
    total_requested,
    total_confirmed,
    shortage,
    ROUND(shortage * 100.0 / NULLIF(total_requested, 0), 1) AS shortage_rate_pct,
    RANK() OVER (ORDER BY total_requested DESC) AS demand_rank,
    RANK() OVER (ORDER BY shortage DESC) AS shortage_rank
FROM product_stats
ORDER BY total_requested DESC
LIMIT 15;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 12: Product Performance by Source Type
-- Own-farm vs outsourced fulfillment comparison
-- ─────────────────────────────────────────────────────────────────────────
SELECT 
    p.source_type,
    COUNT(DISTINCT p.product_id) AS product_count,
    SUM(oi.requested_quantity) AS total_requested,
    SUM(COALESCE(oi.confirmed_quantity, 0)) AS total_confirmed,
    ROUND(
        SUM(COALESCE(oi.confirmed_quantity, 0)) * 100.0 / NULLIF(SUM(oi.requested_quantity), 0),
        2
    ) AS fill_rate_pct
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.source_type
ORDER BY total_requested DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- Query 13: Inventory Snapshot Trend by Category
-- Time-series inventory levels — is stock trending up or down?
-- ─────────────────────────────────────────────────────────────────────────
SELECT 
    DATE_TRUNC('week', inventory_date)::date AS week_start,
    p.category,
    SUM(i.available_quantity) AS total_on_hand,
    AVG(i.available_quantity) AS avg_per_snapshot
FROM inventory i
JOIN products p ON i.product_id = p.product_id
GROUP BY DATE_TRUNC('week', inventory_date), p.category
ORDER BY week_start, category;