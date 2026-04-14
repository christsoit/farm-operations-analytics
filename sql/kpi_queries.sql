-- =========================================
-- KPI 1: Total Order Volume
-- Shows how many cleaned orders were processed
-- =========================================
SELECT 
    COUNT(*) AS total_orders
FROM 
    orders_cleaned;


-- =========================================
-- KPI 2: Total Revenue
-- Calculates total revenue based on confirmed quantity and order item price
-- =========================================
SELECT 
    SUM(COALESCE(oi.confirmed_quantity, 0) * COALESCE(oi.unit_price, 0)) AS total_revenue
FROM 
    order_items oi;


-- =========================================
-- KPI 3: Fill Rate
-- Overall percentage of requested quantity that was successfully confirmed
-- =========================================
SELECT 
    ROUND(
        SUM(COALESCE(confirmed_quantity, 0)) * 100.0 / NULLIF(SUM(requested_quantity), 0),
        2
    ) AS overall_fill_rate_pct
FROM 
    order_items;


-- =========================================
-- KPI 4: Shortage Rate
-- Percentage of requested quantity that was not fulfilled
-- =========================================
SELECT 
    ROUND(
        SUM(requested_quantity - COALESCE(confirmed_quantity, 0)) * 100.0 / NULLIF(SUM(requested_quantity), 0),
        2
    ) AS overall_shortage_rate_pct
FROM 
    order_items;


-- =========================================
-- KPI 5: Top Customers by Revenue
-- Identifies the highest-value buyers based on confirmed item revenue
-- =========================================
SELECT 
    c.customer_name,
    SUM(COALESCE(oi.confirmed_quantity, 0) * COALESCE(oi.unit_price, 0)) AS total_revenue
FROM 
    orders_cleaned o
JOIN 
    order_items oi ON o.order_id = oi.order_id
JOIN 
    customers c ON o.customer_id = c.customer_id
GROUP BY 
    c.customer_name
ORDER BY 
    total_revenue DESC
LIMIT 10;


-- =========================================
-- KPI 6: Top Products by Requested Quantity
-- Shows total demand regardless of fulfillment outcome
-- =========================================
SELECT 
    p.product_name,
    SUM(oi.requested_quantity) AS total_requested
FROM 
    order_items oi
JOIN 
    products p ON oi.product_id = p.product_id
GROUP BY 
    p.product_name
ORDER BY 
    total_requested DESC
LIMIT 10;


-- =========================================
-- KPI 7: Labor Hours by Task Type
-- Tracks operational workload by prep vs delivery
-- =========================================
SELECT 
    task_type,
    SUM(hours_worked) AS total_labor_hours
FROM 
    worker_shifts
GROUP BY 
    task_type
ORDER BY 
    total_labor_hours DESC;


-- =========================================
-- KPI 8: Delivery Performance
-- Shows the distribution of delivery outcomes
-- =========================================
SELECT 
    delivery_status,
    COUNT(*) AS delivery_count,
    ROUND(
        COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM deliveries), 0),
        2
    ) AS percentage
FROM 
    deliveries
GROUP BY 
    delivery_status
ORDER BY 
    delivery_count DESC;


-- =========================================
-- KPI 9: Late Deliveries
-- Identifies deliveries completed after the scheduled time
-- =========================================
SELECT
    delivery_id,
    order_id,
    scheduled_delivery_time,
    actual_delivery_time,
    driver_name
FROM 
    deliveries
WHERE 
    actual_delivery_time > scheduled_delivery_time;


-- =========================================
-- KPI 10: Outsourced vs OwnFarm Product Performance
-- Compares fulfillment performance by product source type
-- =========================================
SELECT 
    p.source_type,
    SUM(oi.requested_quantity) AS total_requested,
    SUM(COALESCE(oi.confirmed_quantity, 0)) AS total_confirmed,
    ROUND(
        SUM(oi.requested_quantity - COALESCE(oi.confirmed_quantity, 0)) * 100.0 / NULLIF(SUM(oi.requested_quantity), 0),
        2
    ) AS shortage_rate_pct
FROM 
    order_items oi
JOIN 
    products p ON oi.product_id = p.product_id
GROUP BY 
    p.source_type;


-- =========================================
-- KPI 11: Order Status Summary
-- Overview of confirmed vs partially fulfilled orders
-- =========================================
SELECT 
    order_status,
    COUNT(*) AS total_orders
FROM 
    orders_cleaned
GROUP BY 
    order_status
ORDER BY 
    total_orders DESC;


-- =========================================
-- KPI 12: Top Products by Shortage Quantity
-- Identifies products with the highest unfulfilled demand
-- =========================================
SELECT
    p.product_name,
    SUM(oi.requested_quantity - COALESCE(oi.confirmed_quantity, 0)) AS shortage_quantity
FROM 
    order_items oi
JOIN 
    products p ON oi.product_id = p.product_id
WHERE 
    oi.requested_quantity > COALESCE(oi.confirmed_quantity, 0)
GROUP BY 
    p.product_name
ORDER BY 
    shortage_quantity DESC;