# Schema

This document describes the relational schema for the Farm Operations Analytics project. The schema models the workflow from raw order intake to cleaned orders, inventory checks, fulfillment preparation, delivery scheduling, labor tracking, and outsourced product sourcing.

## Schema Overview

The schema includes the following core tables:

- `customers`
- `suppliers`
- `workers`
- `products`
- `inventory`
- `incoming_orders_raw`
- `orders_cleaned`
- `order_items`
- `prep_lists`
- `deliveries`
- `worker_shifts`

Dimensions: `customers`, `suppliers`, `workers`, `products`.
Facts: `inventory`, `incoming_orders_raw`, `orders_cleaned`, `order_items`, `prep_lists`, `deliveries`, `worker_shifts`.

## Table Definitions

### `customers`
Stores master data for buyers such as restaurants, grocery customers, wholesale markets, distributors, and individual buyers.

**Primary Key**
- `customer_id`

**Key Columns**
- `customer_name` - standardized customer name
- `market_type` - customer segment: restaurant, grocery, wholesale, distributor, individual, or other
- `region` - delivery or business region
- `signup_date` - date the customer was added
- `is_active` - soft-delete flag (preserves order history when customers churn)

**Purpose**
Provides a clean customer reference for reporting, order tracking, and customer-level analytics.

---

### `suppliers`
Stores produce sources that provide products.

**Primary Key**
- `supplier_id`

**Key Columns**
- `supplier_name` - supplier name
- `supplier_region` - supplier location or region
- `supplier_type` - own_farm, external_farm, distributor, or wholesale_market
- `is_local` - indicates whether the supplier is local
- `is_active` - soft-delete flag

**Purpose**
Supports visibility into product sourcing and links products to their supplier.

---

### `workers`
Centralized dimension for all staff involved in prep, packing, and delivery. Referenced by `prep_lists`, `deliveries`, and `worker_shifts`.

**Primary Key**
- `worker_id`

**Key Columns**
- `worker_name` - standardized worker name
- `role` - prep, driver, multi_role, or supervisor
- `hire_date` - date the worker was hired
- `is_active` - soft-delete flag

**Purpose**
Consolidates worker identity into a single dimension so labor can be analyzed consistently across prep, delivery, and shift activity. Replaces free-text worker names that previously appeared across multiple tables.

---

### `products`
Stores the product catalog for vegetables and produce items.

**Primary Key**
- `product_id`

**Foreign Key**
- `supplier_id` → `suppliers(supplier_id)` (nullable; some products aggregate from multiple sources)

**Key Columns**
- `product_name` - standardized product name
- `category` - product grouping such as leafy greens, herbs, root, or specialty
- `unit` - unit of measure such as box, crate, bunch, or case
- `standard_price` - standard selling price for reference (DECIMAL, must be ≥ 0)
- `source_type` - own_farm, outsourced, or mixed
- `supplier_id` - linked supplier for outsourced products
- `is_active` - soft-delete flag

**Purpose**
Acts as the product master for inventory, order-item tracking, prep work, and demand analysis. Also identifies whether products are farm-grown or externally sourced.

---

### `inventory`
Stores available inventory by product and date.

**Primary Key**
- `inventory_id`

**Foreign Key**
- `product_id` → `products(product_id)`

**Key Columns**
- `inventory_date` - date of available stock snapshot
- `available_quantity` - quantity available on that date (must be ≥ 0)
- `warehouse_location` - storage or staging location

**Grain**
- One row per (`product_id`, `inventory_date`, `warehouse_location`), enforced by a UNIQUE constraint.

**Purpose**
Supports inventory availability checks and helps determine whether incoming orders can be fully or partially fulfilled.

---

### `incoming_orders_raw`
Stores raw incoming orders before they are cleaned and standardized. Captures messy text from text/email/spreadsheet exactly as received.

**Primary Key**
- `raw_order_id`

**Key Columns**
- `customer_name_raw` - customer name as originally received
- `order_text` - raw unstructured order message
- `received_timestamp` - time the order was received
- `source_channel` - text, email, phone, spreadsheet, in_person, or other
- `entered_by` - person or process that logged the raw order

**Purpose**
Preserves the original intake data and supports the workflow from messy order capture to structured order processing.

---

### `orders_cleaned`
Stores cleaned and standardized order headers after raw orders are reviewed and structured. One row per cleaned order (header level; line items live in `order_items`).

**Primary Key**
- `order_id`

**Foreign Keys**
- `raw_order_id` → `incoming_orders_raw(raw_order_id)` (nullable)
- `customer_id` → `customers(customer_id)`

**Key Columns**
- `order_date` - date the cleaned order is recorded
- `requested_delivery_date` - requested delivery date from the customer
- `order_status` - fulfillment status: pending, confirmed, fulfilled, partial, shorted, or cancelled
- `cleaning_status` - standardization/review status: clean, needs_review, incomplete, or rejected
- `total_items` - total line items in the order (denormalized)
- `total_value` - total monetary value of the order (denormalized)
- `notes` - comments or special handling notes

**Purpose**
Represents the cleaned order header and links raw order intake to structured fulfillment and reporting workflows.

---

### `order_items`
Stores line-level order details for products requested within each order.

**Primary Key**
- `order_item_id`

**Foreign Keys**
- `order_id` → `orders_cleaned(order_id)`
- `product_id` → `products(product_id)`

**Key Columns**
- `requested_quantity` - quantity originally requested by the customer (must be > 0)
- `confirmed_quantity` - quantity confirmed after inventory check (nullable; NULL = not yet confirmed; must be ≤ requested_quantity)
- `unit_price` - selling price for that line item (must be ≥ 0)
- `item_status` - line-level status: pending, confirmed, fulfilled, partial, shorted, or cancelled

**Grain**
- One row per (`order_id`, `product_id`), enforced by a UNIQUE constraint.

**Purpose**
Captures product-level demand and fulfillment detail. Critical for calculating fill rate, shortage rate, and product-level order patterns.

---

### `prep_lists`
Stores preparation tasks for confirmed order items that must be picked, packed, or staged.

**Primary Key**
- `prep_id`

**Foreign Keys**
- `order_id` → `orders_cleaned(order_id)`
- `product_id` → `products(product_id)`
- `assigned_worker_id` → `workers(worker_id)` (nullable until prep is assigned)

**Key Columns**
- `quantity_to_prepare` - quantity assigned for prep (must be > 0)
- `prep_status` - pending, assigned, in_progress, completed, or cancelled
- `prep_date` - date the prep activity is scheduled or completed (nullable)

**Purpose**
Translates confirmed orders into operational work instructions for warehouse or field staff, assigned to a worker.

---

### `deliveries`
Stores delivery-level scheduling and status information for outgoing orders.

**Primary Key**
- `delivery_id`

**Foreign Keys**
- `order_id` → `orders_cleaned(order_id)`
- `driver_worker_id` → `workers(worker_id)` (nullable until a driver is assigned)

**Key Columns**
- `scheduled_delivery_time` - planned delivery timestamp
- `actual_delivery_time` - actual delivery timestamp (nullable until delivered)
- `delivery_status` - scheduled, in_transit, delivered, failed, or cancelled
- `delivery_address` - destination address

**Grain**
- One row per order (UNIQUE constraint on `order_id`) as an MVP simplification.

**Purpose**
Supports delivery tracking, on-time performance analysis, and driver workload planning. On-time is defined as a delivered order whose actual delivery date matches the scheduled date.

---

### `worker_shifts`
Stores labor activity for workers involved in prep, packing, delivery, and other tasks.

**Primary Key**
- `shift_id`

**Foreign Keys**
- `worker_id` → `workers(worker_id)`
- `related_order_id` → `orders_cleaned(order_id)` (nullable; some shifts aren't tied to a specific order)

**Key Columns**
- `shift_date` - work date
- `task_type` - prep, delivery, cleaning, inventory, admin, or other
- `hours_worked` - number of hours worked (must be > 0 and ≤ 24)
- `hourly_rate` - pay rate (must be ≥ 0)
- `notes` - additional work notes

**Purpose**
Supports labor usage analysis and operational cost visibility by worker, task, and order. Note: `total_payment` is intentionally not stored — it's computed as `hours_worked * hourly_rate` in queries.

---

## Key Relationships

- One `supplier` provides many `products`
- One `customer` places many `orders_cleaned`
- One `raw_order` maps to one `orders_cleaned` record
- One `order` has many `order_items`
- One `product` appears in many `inventory` records
- One `product` appears in many `order_items`
- One `order` has many `prep_lists`
- One `order` has one `delivery` (MVP simplification)
- One `order` can be linked to many `worker_shifts`
- One `worker` is referenced by many `prep_lists`, `deliveries`, and `worker_shifts`

## Workflow Mapping

1. Raw buyer requests are stored in `incoming_orders_raw`
2. Cleaned order headers are stored in `orders_cleaned`
3. Product-level order details are stored in `order_items`
4. Product availability is checked using `inventory`
5. Preparation tasks are stored in `prep_lists`
6. Delivery execution is tracked in `deliveries`
7. Labor usage is tracked in `worker_shifts`

## Business Questions Supported

- Which products are ordered most often?
- Which customers generate the most revenue?
- How often do shortages affect fulfillment?
- What is the overall fill rate?
- How does on-time delivery performance trend over time?
- How does driver productivity vary by volume and on-time rate?
- Which market segments drive the most revenue?
- Are outsourced products more likely to have shortages than own-farmed products?

## Design Notes

- `incoming_orders_raw` preserves messy source data before standardization
- `orders_cleaned` links cleaned orders back to the original raw intake via `raw_order_id`
- `order_items` separates requested from confirmed quantity to support shortage and fulfillment analysis
- `workers` is a centralized dimension referenced by `prep_lists` (`assigned_worker_id`), `deliveries` (`driver_worker_id`), and `worker_shifts` (`worker_id`) — replacing free-text worker names for consistent labor analysis
- `source_type` in `products` distinguishes farm-grown (`own_farm`) from externally sourced (`outsourced`) items, with `mixed` for aggregated products
- `total_items` and `total_value` on `orders_cleaned` are denormalized for query convenience (see `decisions.md` for the known reconciliation note)
- `total_payment` is intentionally not stored on `worker_shifts` — it's computed from `hours_worked * hourly_rate` in queries
- CHECK constraints enforce valid enum values on all status and type columns