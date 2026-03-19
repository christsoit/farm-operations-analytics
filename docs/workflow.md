# Part One: Operational Workflow

This workflow tracks the lifecycle of farm produce from the moment a buyer places an order to the moment it is delivered and labor activity is recorded.

## 1. Market Order Submission
Buyers such as restaurants, grocery stores, and wholesale markets submit produce orders through unstructured channels such as text messages, email, spreadsheets, or informal order lists. In this project, these requests are represented in the `incoming_orders_raw` table.

## 2. Order Intake and Cleaning
The raw order data is reviewed, standardized, and transformed into structured records. Customer names, product names, quantities, and units are cleaned so they can be stored consistently in the `orders_cleaned` and `order_items` tables.

## 3. Inventory Availability Check
The system checks the requested order quantities against the `inventory` table to determine whether items are available in full, partially available, or unavailable.

## 4. Order Confirmation
Based on inventory availability, each order is marked as fully fulfilled, partially fulfilled, or short. Confirmed quantities are then prepared for packing and delivery planning.

## 5. Prep List Generation
Confirmed order quantities are translated into operational prep tasks. Workers use these tasks to identify what needs to be picked, washed, packed, or staged for outgoing delivery.

## 6. Delivery Scheduling
Prepared orders are assigned delivery records, routes, or delivery windows. This allows the farm to organize outbound shipments and track which orders are ready for delivery.

## 7. Worker Hours and Labor Tracking
Labor activity related to picking, packing, and delivery is recorded in the `worker_shifts` table. This supports analysis of labor usage, worker productivity, and operational workload.

## 8. Operational Dashboard
Data from the workflow is summarized into reporting outputs and dashboard views. Managers can use these outputs to monitor order volume, fill rate, shortages, labor usage, and delivery performance.

# Part Two: Key Business Questions

- Which products are ordered most often?
- Which customers generate the most order volume?
- How often do stockouts affect fulfillment?
- What is the overall order fill rate?
- How much labor is being used across prep and delivery activities?
- Where are the main operational bottlenecks?

# Part Three: Future Enhancement

A future enhancement could automate the order intake step using n8n and LLM-based text parsing to convert messy incoming messages into structured database records.