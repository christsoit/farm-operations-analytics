-- =========================================
-- CUSTOMERS — Dimension table for buyers
-- =========================================
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,                    
    customer_name VARCHAR(100) NOT NULL,
    market_type VARCHAR(50) NOT NULL,                  -- 'restaurant', 'grocery', 'wholesale'
    region VARCHAR(50),
    signup_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,                    -- Soft delete flag preserves order history when customers churn
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_customer_market_type CHECK (
        market_type IN ('restaurant', 'grocery', 'wholesale', 'distributor', 'individual', 'other')
    )
);

-- =========================================
-- SUPPLIERS — Dimension table for produce sources
-- =========================================
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    supplier_region VARCHAR(50),
    supplier_type VARCHAR(50) NOT NULL,                -- 'own_farm', 'external_farm', 'distributor'
    is_local BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_supplier_type CHECK (
        supplier_type IN ('own_farm', 'external_farm', 'distributor', 'wholesale_market')
    )
);

-- =========================================
-- WORKERS — Dimension table for farm staff 
-- =========================================
CREATE TABLE workers (
    worker_id SERIAL PRIMARY KEY,
    worker_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL,                         -- 'prep', 'driver', 'multi_role'
    hire_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_worker_role CHECK (
        role IN ('prep', 'driver', 'multi_role', 'supervisor')
    )
);

-- =========================================
-- PRODUCTS — Dimension table for produce items
-- =========================================
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    standard_price DECIMAL(10, 2) NOT NULL,
    source_type VARCHAR(30) NOT NULL,
    -- Some products may not have a single supplier (e.g., aggregated from multiple)
    supplier_id INT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_products_supplier 
        FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    
    CONSTRAINT chk_product_source_type CHECK (
        source_type IN ('own_farm', 'outsourced', 'mixed')
    ),
    
    CONSTRAINT chk_product_price_positive CHECK (
        standard_price >= 0
    )
);

-- =========================================
-- INVENTORY — Daily product availability snapshot
-- =========================================
CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    inventory_date DATE NOT NULL,
    available_quantity DECIMAL(10, 2) NOT NULL,
    warehouse_location VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_inventory_product 
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    
    CONSTRAINT chk_inventory_quantity_non_negative CHECK (
        available_quantity >= 0
    ),
    
    -- Grain: one row per product, per location, per day
    CONSTRAINT uq_inventory_grain 
        UNIQUE (product_id, inventory_date, warehouse_location)
);

-- =========================================
-- INCOMING_ORDERS_RAW — Original unstructured order intake
-- Captures messy text from text/email/spreadsheet exactly as received
-- =========================================
CREATE TABLE incoming_orders_raw (
    raw_order_id SERIAL PRIMARY KEY,
    customer_name_raw VARCHAR(100),
    order_text TEXT NOT NULL,
    received_timestamp TIMESTAMP NOT NULL,
    source_channel VARCHAR(50) NOT NULL,
    entered_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_raw_order_source_channel CHECK (
        source_channel IN ('text', 'email', 'phone', 'spreadsheet', 'in_person', 'other')
    )
);

-- =========================================
-- ORDERS_CLEANED — Parsed and structured order data
-- One row per cleaned order (header level — line items live in order_items)
-- =========================================
CREATE TABLE orders_cleaned (
    order_id SERIAL PRIMARY KEY,
    raw_order_id INT,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    requested_delivery_date DATE,
    order_status VARCHAR(50) NOT NULL,
    cleaning_status VARCHAR(50) NOT NULL,
    -- Denormalized for query performance; refresh job keeps these accurate
    total_items INT,
    total_value DECIMAL(10, 2),
    notes VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_orders_raw 
        FOREIGN KEY (raw_order_id) REFERENCES incoming_orders_raw(raw_order_id),
    
    CONSTRAINT fk_orders_customer 
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    
    CONSTRAINT chk_order_status CHECK (
        order_status IN ('pending', 'confirmed', 'fulfilled', 'partial', 'shorted', 'cancelled')
    ),
    
    CONSTRAINT chk_cleaning_status CHECK (
        cleaning_status IN ('clean', 'needs_review', 'incomplete', 'rejected')
    )
);

-- =========================================
-- ORDER_ITEMS — Line items within each order
-- Grain: one row per order × product
-- =========================================
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    requested_quantity DECIMAL(10, 2) NOT NULL,
    -- NULL means item not yet confirmed (still in cleaning/review)
    confirmed_quantity DECIMAL(10, 2),
    unit_price DECIMAL(10, 2) NOT NULL,
    item_status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_order_items_order 
        FOREIGN KEY (order_id) REFERENCES orders_cleaned(order_id),
    
    CONSTRAINT fk_order_items_product 
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    
    CONSTRAINT chk_order_item_status CHECK (
        item_status IN ('pending', 'confirmed', 'fulfilled', 'partial', 'shorted', 'cancelled')
    ),
    
    CONSTRAINT chk_order_item_quantities CHECK (
        requested_quantity > 0
        AND (confirmed_quantity IS NULL OR confirmed_quantity >= 0)
        AND (confirmed_quantity IS NULL OR confirmed_quantity <= requested_quantity)
    ),
    
    CONSTRAINT chk_order_item_price CHECK (
        unit_price >= 0
    ),
    
    -- Grain: same product shouldn't appear twice in the same order
    CONSTRAINT uq_order_items_grain 
        UNIQUE (order_id, product_id)
);

-- =========================================
-- PREP_LISTS — Worker tasks for fulfilling orders
-- Grain: one row per order × product (prep task)
-- =========================================
CREATE TABLE prep_lists (
    prep_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_to_prepare DECIMAL(10, 2) NOT NULL,
    prep_status VARCHAR(50) NOT NULL,
    -- NULL allowed when prep hasn't been assigned yet
    assigned_worker_id INT,
    prep_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_prep_lists_order 
        FOREIGN KEY (order_id) REFERENCES orders_cleaned(order_id),
    
    CONSTRAINT fk_prep_lists_product 
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    
    CONSTRAINT fk_prep_lists_worker 
        FOREIGN KEY (assigned_worker_id) REFERENCES workers(worker_id),
    
    CONSTRAINT chk_prep_status CHECK (
        prep_status IN ('pending', 'assigned', 'in_progress', 'completed', 'cancelled')
    ),
    
    CONSTRAINT chk_prep_quantity_positive CHECK (
        quantity_to_prepare > 0
    )
);

-- =========================================
-- DELIVERIES — Outbound delivery records
-- Grain: one row per order
-- =========================================
CREATE TABLE deliveries (
    delivery_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    scheduled_delivery_time TIMESTAMP NOT NULL,
    -- NULL until delivery actually completes
    actual_delivery_time TIMESTAMP,
    delivery_status VARCHAR(50) NOT NULL,
    -- NULL allowed when driver not yet assigned
    driver_worker_id INT,
    delivery_address VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_deliveries_order 
        FOREIGN KEY (order_id) REFERENCES orders_cleaned(order_id),
    
    CONSTRAINT fk_deliveries_driver 
        FOREIGN KEY (driver_worker_id) REFERENCES workers(worker_id),
    
    CONSTRAINT chk_delivery_status CHECK (
        delivery_status IN ('scheduled', 'in_transit', 'delivered', 'failed', 'cancelled')
    ),
    
    -- One delivery per order (assuming no split deliveries for MVP)
    CONSTRAINT uq_deliveries_order 
        UNIQUE (order_id)
);

-- =========================================
-- WORKER_SHIFTS — Labor activity records
-- Grain: one row per worker × shift_date × task_type × order
-- =========================================
CREATE TABLE worker_shifts (
    shift_id SERIAL PRIMARY KEY,
    worker_id INT NOT NULL,
    shift_date DATE NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    hours_worked DECIMAL(5, 2) NOT NULL,
    hourly_rate DECIMAL(10, 2) NOT NULL,
    -- NULL allowed because some shifts (e.g., warehouse cleanup) aren't tied to a specific order
    related_order_id INT,
    notes VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_worker_shifts_worker 
        FOREIGN KEY (worker_id) REFERENCES workers(worker_id),
    
    CONSTRAINT fk_worker_shifts_order 
        FOREIGN KEY (related_order_id) REFERENCES orders_cleaned(order_id),
    
    CONSTRAINT chk_worker_shift_task_type CHECK (
        task_type IN ('prep', 'delivery', 'cleaning', 'inventory', 'admin', 'other')
    ),
    
    CONSTRAINT chk_worker_shift_hours CHECK (
        hours_worked > 0 AND hours_worked <= 24
    ),
    
    CONSTRAINT chk_worker_shift_rate CHECK (
        hourly_rate >= 0
    )
);