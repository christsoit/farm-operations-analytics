# Schema Documentation

This document describes the relational schema for the Farm Operations Analytics project. The schema is designed to model the workflow from raw order intake to cleaned orders, fulfillment preparation, delivery scheduling, and labor tracking.

## Schema Overview

The MVP schema includes the following core tables:

- `customers`
- `products`
- `inventory`
- `incoming_orders_raw`
- `orders_cleaned`
- `order_items`
- `prep_lists`
- `deliveries`
- `worker_shifts`

## Table Definitions

### `customers`
Stores master data for farm buyers such as wholesale markets, restaurants, and grocery customers.

**Primary Key**
- `customer_id`

**Key Columns**
- `customer_name` - standardized customer name
- `market_type` - customer segment such as restaurant, grocery, or wholesale market
- `region` - delivery or business region
- `signup_date` - date the customer was added

**Purpose**
This table provides a clean customer reference for reporting, order tracking, and customer-level analytics.

---

### `products`
Stores the product catalog for vegetables and produce items sold by the farm.

**Primary Key**
- `product_id`

**Key Columns**
- `product_name` - standardized product name
- `category` - product grouping such as leafy greens, root vegetables, or herbs
- `unit` - unit of measure such as box, crate, bunch, or pound
- `standard_price` - standard selling price for reporting or reference

**Purpose**
This table acts as the product master for inventory, order item tracking, prep work, and demand analysis.

---

### `inventory`
Stores available inventory by product and date.

**Primary Key**
- `inventory_id`

**Foreign Key**
- `product_id` → `products(product_id)`

**Key Columns**
- `inventory_date` - date of available stock snapshot
- `available_quantity` - quantity available on that date
- `warehouse_location` - storage or staging location

**Purpose**
This table supports inventory availability checks and helps determine whether incoming orders can be fully or partially fulfilled.

---

### `incoming_orders_raw`
Stores raw incoming orders before they are cleaned and standardized.

**Primary Key**
- `raw_order_id`

**Key Columns**
- `customer_name_raw` - customer name as originally received
- `order_text` - raw unstructured order message
- `received_timestamp` - time the order was received
- `source_channel` - origin such as text, email, spreadsheet, or WhatsApp
- `entered_by` - person or process that logged the raw order

**Purpose**
This table preserves the original intake data and supports the workflow from messy order capture to structured order processing.

---

### `orders_cleaned`
Stores cleaned and standardized order headers after raw orders are reviewed and structured.

**Primary Key**
- `order_id`

**Foreign Keys**
- `raw_order_id` → `incoming_orders_raw(raw_order_id)`
- `customer_id` → `customers(customer_id)`

**Key Columns**
- `order_date` - date the cleaned order is recorded
- `requested_delivery_date` - requested delivery date from the customer
- `order_status` - current fulfillment status such as confirmed, partial, or short
- `cleaning_status` - status of order standardization or review
- `total_items` - total number of line items in the order
- `total_value` - total monetary value of the order
- `notes` - comments or special handling notes

**Purpose**
This table represents the cleaned order header and links raw order intake to structured fulfillment and reporting workflows.

---

### `order_items`
Stores line-level order details for products requested within each order.

**Primary Key**
- `order_item_id`

**Foreign Keys**
- `order_id` → `orders_cleaned(order_id)`
- `product_id` → `products(product_id)`

**Key Columns**
- `requested_quantity` - quantity originally requested by the customer
- `confirmed_quantity` - quantity confirmed after inventory check
- `unit_price` - selling price for that line item
- `item_status` - line-level status such as fulfilled, partial, or unavailable

**Purpose**
This table captures product-level demand and fulfillment detail. It is critical for calculating fill rate, shortage rate, and product-level order patterns.

---

### `prep_lists`
Stores preparation tasks for confirmed order items that must be picked, packed, or staged.

**Primary Key**
- `prep_id`

**Foreign Keys**
- `order_id` → `orders_cleaned(order_id)`
- `product_id` → `products(product_id)`

**Key Columns**
- `quantity_to_prepare` - quantity assigned for prep
- `prep_status` - current prep status such as pending, in progress, or complete
- `assigned_worker` - worker assigned to the prep task
- `prep_date` - date the prep activity is scheduled or completed

**Purpose**
This table translates confirmed orders into operational work instructions for warehouse or field staff.

---

### `deliveries`
Stores delivery-level scheduling and status information for outgoing orders.

**Primary Key**
- `delivery_id`

**Foreign Key**
- `order_id` → `orders_cleaned(order_id)`

**Key Columns**
- `scheduled_delivery_time` - planned delivery timestamp
- `actual_delivery_time` - actual delivery timestamp
- `delivery_status` - delivery outcome such as scheduled, delivered, or delayed
- `driver_name` - assigned driver
- `delivery_address` - destination address for the order

**Purpose**
This table supports delivery tracking, on-time performance analysis, and route or workload planning.

---

### `worker_shifts`
Stores labor activity for workers involved in order prep, packing, or delivery support.

**Primary Key**
- `shift_id`

**Foreign Key**
- `related_order_id` → `orders_cleaned(order_id)`

**Key Columns**
- `worker_name` - employee or contractor name
- `shift_date` - work date
- `task_type` - work category such as prep, packing, loading, or delivery
- `hours_worked` - number of hours worked
- `hourly_rate` - pay rate
- `total_payment` - total paid for the shift
- `notes` - additional work notes

**Purpose**
This table supports labor usage analysis, payroll tracking, and operational cost visibility by order or task type.

## Key Relationships

The main relationships in the schema are:

- One `customer` can have many `orders_cleaned`
- One `raw_order` can be transformed into one cleaned order record
- One `order` can have many `order_items`
- One `product` can appear in many `inventory` records
- One `product` can appear in many `order_items`
- One `order` can have many `prep_lists`
- One `order` can have one or more `deliveries`
- One `order` can be linked to many `worker_shifts`

## Workflow Mapping

This schema supports the business workflow in the following way:

1. Raw buyer requests are stored in `incoming_orders_raw`
2. Cleaned order headers are stored in `orders_cleaned`
3. Product-level order details are stored in `order_items`
4. Product availability is checked using `inventory`
5. Preparation tasks are stored in `prep_lists`
6. Delivery execution is tracked in `deliveries`
7. Labor usage is tracked in `worker_shifts`

## Business Questions Supported

This schema is designed to support analysis such as:

- Which products are ordered most often?
- Which customers generate the most order volume?
- How often do stockouts affect fulfillment?
- What is the overall fill rate?
- How much labor is used across prep and delivery work?
- Where are the main operational bottlenecks?

## Design Notes

- `incoming_orders_raw` preserves messy source data before standardization
- `orders_cleaned` links cleaned orders back to the original raw intake
- `order_items` separates requested quantity from confirmed quantity to support shortage and fulfillment analysis
- `worker_shifts` includes `related_order_id` so labor can be connected to specific orders
- `total_payment` is stored for reporting convenience in the MVP, although it can also be derived from `hours_worked * hourly_rate`