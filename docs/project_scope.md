## Business Context
The farm operates as a produce distributor, supplying fresh vegetables to wholesale markets and buyers. Daily operations involve receiving orders across various unstructured channels (text messages, email, spreadsheets, or informal order lists). Because these orders are often inconsistent, the business must clean and standardize them before checking stock availability, preparing items, scheduling deliveries, and tracking worker labor. This project simulates that workflow and turns it into structured operational reporting.

## Main Problem
Farm operations suffer from inefficiencies due to manual, messy data entry. Unstructured incoming orders lead to processing delays and data errors. Furthermore, limited inventory visibility results in partial fulfillments (shortages), while poor operational tracking makes it difficult to identify bottlenecks in worker productivity and delivery scheduling (especially on peak days).

## Objective
To design a relational data model and build an operational dashboard that provides end-to-end visibility into the farm's fulfillment pipeline. The goal is to use data to improve order intake speed, increase the order fill rate, optimize labor costs, and reduce delivery delays.

## In Scope for MVP
- Relational SQL schema for core operational entities, including customers, products, inventory, raw orders, cleaned orders, order items, deliveries, worker shifts, and prep lists
- Sample raw and cleaned datasets to simulate messy order intake and standardized reporting
- SQL data quality checks to identify issues such as missing items, invalid quantities, and duplicate orders
- KPI and reporting queries for order volume, fill rate, shortage rate, customer demand, labor usage, and delivery performance
- Dashboard to present business metrics and operational insights
- Documentation of key findings, assumptions, and recommendations

## Out of Scope for MVP
- Live production database connection
- Real-time backend APIs or CRUD workflows
- Active automation deployment using n8n or LLM-based parsing
- Mobile applications for drivers or warehouse workers
- Third-party integrations such as accounting, routing, or authentication systems

## Future Enhancements
- Automated order parsing workflow using n8n and LLM-based text standardization
- Interactive frontend application for operations monitoring
- Live database and backend API integration
- Delivery route optimization and external system integrations