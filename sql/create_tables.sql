CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    market_type VARCHAR(50),
    region VARCHAR(50),
    signup_date DATE
);

CREATE TABLE suppliers (
    supplier_id INT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    supplier_region VARCHAR(50),
    supplier_type VARCHAR(50),
    is_local BOOLEAN
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    unit VARCHAR(20),
    standard_price DECIMAL(10, 2),
    source_type VARCHAR(30),
    supplier_id INT,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE inventory (
    inventory_id INT PRIMARY KEY,
    product_id INT NOT NULL,
    inventory_date DATE NOT NULL,
    available_quantity DECIMAL(10, 2) NOT NULL,
    warehouse_location VARCHAR(50),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE incoming_orders_raw (
    raw_order_id INT PRIMARY KEY,
    customer_name_raw VARCHAR(100),
    order_text TEXT NOT NULL,
    received_timestamp TIMESTAMP NOT NULL,
    source_channel VARCHAR(50),
    entered_by VARCHAR(100)
);

CREATE TABLE orders_cleaned (
    order_id INT PRIMARY KEY,
    raw_order_id INT,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    requested_delivery_date DATE,
    order_status VARCHAR(50),
    cleaning_status VARCHAR(50),
    total_items INT,
    total_value DECIMAL(10, 2),
    notes VARCHAR(255),
    FOREIGN KEY (raw_order_id) REFERENCES incoming_orders_raw(raw_order_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    requested_quantity DECIMAL(10, 2) NOT NULL,
    confirmed_quantity DECIMAL(10, 2),
    unit_price DECIMAL(10, 2),
    item_status VARCHAR(50),
    FOREIGN KEY (order_id) REFERENCES orders_cleaned(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE prep_lists (
    prep_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_to_prepare DECIMAL(10, 2) NOT NULL,
    prep_status VARCHAR(50),
    assigned_worker VARCHAR(100),
    prep_date DATE,
    FOREIGN KEY (order_id) REFERENCES orders_cleaned(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE deliveries (
    delivery_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    scheduled_delivery_time TIMESTAMP,
    actual_delivery_time TIMESTAMP,
    delivery_status VARCHAR(50),
    driver_name VARCHAR(100),
    delivery_address VARCHAR(255),
    FOREIGN KEY (order_id) REFERENCES orders_cleaned(order_id)
);

CREATE TABLE worker_shifts (
    shift_id INT PRIMARY KEY,
    worker_name VARCHAR(100) NOT NULL,
    shift_date DATE NOT NULL,
    task_type VARCHAR(50),
    hours_worked DECIMAL(5, 2) NOT NULL,
    hourly_rate DECIMAL(10, 2) NOT NULL,
    total_payment DECIMAL(10, 2),
    related_order_id INT,
    notes VARCHAR(255),
    FOREIGN KEY (related_order_id) REFERENCES orders_cleaned(order_id)
);