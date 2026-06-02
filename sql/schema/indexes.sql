-- =========================================
-- FARM OPERATIONS ANALYTICS — INDEXES
-- Performance indexes for common query patterns
-- =========================================

-- =========================================
-- FOREIGN KEY INDEXES
-- Postgres doesn't auto-index FKs. These speed up JOINs and FK lookups.
-- =========================================

-- products.supplier_id — JOINed when analyzing products by supplier
CREATE INDEX idx_products_supplier ON products(supplier_id);

-- inventory.product_id — JOINed when checking inventory per product
CREATE INDEX idx_inventory_product ON inventory(product_id);

-- orders_cleaned.customer_id — heavily used in customer revenue analytics
CREATE INDEX idx_orders_customer ON orders_cleaned(customer_id);

-- orders_cleaned.raw_order_id — used to trace from cleaned back to raw
CREATE INDEX idx_orders_raw ON orders_cleaned(raw_order_id);

-- order_items.product_id — used in product demand and revenue queries
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- prep_lists.worker_id — used in worker productivity queries
CREATE INDEX idx_prep_lists_worker ON prep_lists(assigned_worker_id);

-- prep_lists.order_id — used to find prep tasks for a given order
CREATE INDEX idx_prep_lists_order ON prep_lists(order_id);

-- prep_lists.product_id — used when analyzing prep work per product
CREATE INDEX idx_prep_lists_product ON prep_lists(product_id);

-- deliveries.driver_worker_id — used in driver performance queries
CREATE INDEX idx_deliveries_driver ON deliveries(driver_worker_id);

-- worker_shifts.worker_id — used in labor analytics by worker
CREATE INDEX idx_worker_shifts_worker ON worker_shifts(worker_id);

-- worker_shifts.related_order_id — used to tie labor cost to orders
CREATE INDEX idx_worker_shifts_order ON worker_shifts(related_order_id);


-- =========================================
-- DATE-BASED INDEXES
-- Most analytics queries filter or group by date. Index date columns.
-- =========================================

-- orders_cleaned.order_date — filtered in time-series analytics
CREATE INDEX idx_orders_order_date ON orders_cleaned(order_date);

-- orders_cleaned.requested_delivery_date — filtered in delivery planning
CREATE INDEX idx_orders_delivery_date ON orders_cleaned(requested_delivery_date);

-- inventory.inventory_date — filtered in inventory trend queries
CREATE INDEX idx_inventory_date ON inventory(inventory_date);

-- worker_shifts.shift_date — filtered in labor cost queries
CREATE INDEX idx_worker_shifts_date ON worker_shifts(shift_date);

-- deliveries.scheduled_delivery_time — filtered in delivery schedule queries
CREATE INDEX idx_deliveries_scheduled ON deliveries(scheduled_delivery_time);


-- =========================================
-- STATUS / FILTER INDEXES
-- Status columns are heavily filtered. Index them for query speed.
-- =========================================

-- orders_cleaned.order_status — common filter (e.g., "show me pending orders")
CREATE INDEX idx_orders_status ON orders_cleaned(order_status);

-- order_items.item_status — used in fill rate and shortage analytics
CREATE INDEX idx_order_items_status ON order_items(item_status);

-- deliveries.delivery_status — used in delivery performance queries
CREATE INDEX idx_deliveries_status ON deliveries(delivery_status);


-- =========================================
-- COMPOSITE INDEX FOR HIGH-VALUE QUERY PATTERN
-- "Show me a customer's order history sorted by date" is extremely common.
-- A composite index speeds this up dramatically.
-- =========================================

CREATE INDEX idx_orders_customer_date 
    ON orders_cleaned(customer_id, order_date DESC);

-- This single index supports queries like:
--   SELECT * FROM orders_cleaned 
--   WHERE customer_id = 47 
--   ORDER BY order_date DESC;