-- customers
INSERT INTO customers (customer_id, customer_name, market_type, region, signup_date) VALUES
(1, 'Golden Basket Market', 'Wholesale Market', 'San Jose', '2025-01-15'),
(2, 'Bay Fresh Produce Market', 'Wholesale Market', 'San Francisco', '2025-02-10'),
(3, 'Harbor Wholesale Market', 'Wholesale Market', 'Oakland', '2025-03-05'),
(4, 'Sunrise Market', 'Wholesale Market', 'Santa Clara', '2025-04-12'),
(5, 'Evergreen Produce Center', 'Wholesale Market', 'San Jose', '2025-05-20'),
(6, 'Lee Family Kitchen', 'Individual Buyer', 'Gilroy', '2025-06-18'),
(7, 'Wong Produce Buyer', 'Individual Buyer', 'Morgan Hill', '2025-07-09'),
(8, 'Fresh Home Foods', 'Individual Buyer', 'Gilroy', '2025-08-14'),
(9, 'Chen Market Pickup', 'Individual Buyer', 'San Jose', '2025-09-03');

-- suppliers
INSERT INTO suppliers (supplier_id, supplier_name, supplier_region, supplier_type, is_local) VALUES
(1, 'Northern Harvest Farm', 'Central Valley', 'External Farm', FALSE),
(2, 'Valley Green Growers', 'Salinas', 'External Farm', FALSE),
(3, 'Pacific Fresh Farms', 'Bakersfield', 'External Farm', FALSE);

-- products
INSERT INTO products (product_id, product_name, category, unit, standard_price, source_type, supplier_id) VALUES
(1, 'Bok Choy', 'Leafy Greens', 'box', 18.00, 'OwnFarm', NULL),
(2, 'Napa Cabbage', 'Leafy Greens', 'crate', 22.00, 'OwnFarm', NULL),
(3, 'Choy Sum', 'Leafy Greens', 'box', 20.00, 'OwnFarm', NULL),
(4, 'Chinese Broccoli', 'Leafy Greens', 'box', 24.00, 'OwnFarm', NULL),
(5, 'Spinach', 'Leafy Greens', 'box', 16.00, 'OwnFarm', NULL),
(6, 'Water Spinach', 'Leafy Greens', 'box', 21.00, 'OwnFarm', NULL),
(7, 'Baby Bok Choy', 'Leafy Greens', 'box', 19.00, 'OwnFarm', NULL),
(8, 'Green Onion', 'Herbs', 'bunch', 12.00, 'Outsourced', 1),
(9, 'Cilantro', 'Herbs', 'bunch', 10.00, 'Outsourced', 2),
(10, 'Tomato', 'Fruit Vegetables', 'case', 28.00, 'Outsourced', 1),
(11, 'Okra', 'Fruit Vegetables', 'box', 30.00, 'Outsourced', 3),
(12, 'Romaine Lettuce', 'Leafy Greens', 'box', 19.00, 'Outsourced', 2);

-- inventory
INSERT INTO inventory (inventory_id, product_id, inventory_date, available_quantity, warehouse_location) VALUES
(1, 1, '2026-03-31', 55.00, 'Warehouse A'),
(2, 2, '2026-03-31', 18.00, 'Warehouse A'),
(3, 3, '2026-03-31', 20.00, 'Warehouse B'),
(4, 4, '2026-03-31', 10.00, 'Warehouse B'),
(5, 5, '2026-03-31', 22.00, 'Cold Room 1'),
(6, 6, '2026-03-31', 12.00, 'Warehouse A'),
(7, 7, '2026-03-31', 8.00, 'Cold Room 2'),
(8, 8, '2026-03-31', 70.00, 'Cold Room 1'),
(9, 9, '2026-03-31', 20.00, 'Cold Room 2'),
(10, 10, '2026-03-31', 12.00, 'Warehouse C'),
(11, 11, '2026-03-31', 4.00, 'Warehouse C'),
(12, 12, '2026-03-31', 12.00, 'Cold Room 2');

-- incoming_orders_raw
INSERT INTO incoming_orders_raw (raw_order_id, customer_name_raw, order_text, received_timestamp, source_channel, entered_by) VALUES
(5001, 'Golden Basket Mkt', 'Need 14 bx bok choy, 10 crates napa, 6 green onion for Wed AM', '2026-03-31 17:45:00', 'SMS', 'Chris'),
(5002, 'Bay Fresh Produce', 'send 12 choy sum 8 chinese broc 10 cs tomato for tomorrow', '2026-03-31 18:10:00', 'WhatsApp', 'Chris'),
(5003, 'Harbor Wholesale', 'Need 20 spinach and 12 baby bok for Wed dock drop', '2026-03-31 18:35:00', 'Email', 'Amy'),
(5004, 'Sunrise Mkt', '10 napa, 8 romaine, 10 cilantro for Wed', '2026-03-31 19:00:00', 'SMS', 'Chris'),
(5005, 'Evergreen Produce Ctr', 'Need 15 bok choy + 10 water spinach + 6 okra', '2026-03-31 19:20:00', 'Spreadsheet', 'System'),
(5006, 'Lee Family Kitchen', 'need 3 tomato and 2 cilantro for lunch tomorrow', '2026-03-31 19:45:00', 'WhatsApp', 'Chris'),
(5007, 'Wong Produce', '2 bok choy 2 napa 1 green onion pickup tmw', '2026-03-31 20:05:00', 'SMS', 'Chris'),
(5008, 'Fresh Home Foods', 'Please reserve 4 spinach, 2 tomato, 2 romaine for Thursday pickup', '2026-03-31 20:30:00', 'Email', 'Amy');

-- orders_cleaned
INSERT INTO orders_cleaned (
    order_id, raw_order_id, customer_id, order_date, requested_delivery_date,
    order_status, cleaning_status, total_items, total_value, notes
) VALUES
(1001, 5001, 1, '2026-03-31', '2026-04-01', 'Partial Fulfilled', 'Cleaned', 3, 500.00, 'Napa cabbage partially fulfilled due to limited stock'),
(1002, 5002, 2, '2026-03-31', '2026-04-01', 'Partial Fulfilled', 'Cleaned', 3, 628.00, 'Tomato partially fulfilled due to outsourced stock shortage'),
(1003, 5003, 3, '2026-03-31', '2026-04-01', 'Partial Fulfilled', 'Cleaned', 2, 440.00, 'Baby bok choy limited by available harvest'),
(1004, 5004, 4, '2026-03-31', '2026-04-01', 'Confirmed', 'Cleaned', 3, 472.00, 'Confirmed in full'),
(1005, 5005, 5, '2026-03-31', '2026-04-01', 'Partial Fulfilled', 'Cleaned', 3, 600.00, 'Okra partially fulfilled due to low outsourced inventory'),
(1006, 5006, 6, '2026-03-31', '2026-04-01', 'Confirmed', 'Cleaned', 2, 104.00, 'Small customer delivery confirmed'),
(1007, 5007, 7, '2026-03-31', '2026-04-01', 'Partial Fulfilled', 'Cleaned', 3, 48.00, 'Napa cabbage unavailable for pickup order'),
(1008, 5008, 8, '2026-03-31', '2026-04-02', 'Confirmed', 'Cleaned', 3, 158.00, 'Pickup order confirmed');

-- order_items
INSERT INTO order_items (
    order_item_id, order_id, product_id, requested_quantity, confirmed_quantity, unit_price, item_status
) VALUES
(1, 1001, 1, 14.00, 14.00, 18.00, 'Fulfilled'),
(2, 1001, 2, 10.00, 8.00, 22.00, 'Partial'),
(3, 1001, 8, 6.00, 6.00, 12.00, 'Fulfilled'),
(4, 1002, 3, 12.00, 12.00, 20.00, 'Fulfilled'),
(5, 1002, 4, 8.00, 8.00, 24.00, 'Fulfilled'),
(6, 1002, 10, 10.00, 7.00, 28.00, 'Partial'),
(7, 1003, 5, 20.00, 18.00, 16.00, 'Partial'),
(8, 1003, 7, 12.00, 8.00, 19.00, 'Partial'),
(9, 1004, 2, 10.00, 10.00, 22.00, 'Fulfilled'),
(10, 1004, 12, 8.00, 8.00, 19.00, 'Fulfilled'),
(11, 1004, 9, 10.00, 10.00, 10.00, 'Fulfilled'),
(12, 1005, 1, 15.00, 15.00, 18.00, 'Fulfilled'),
(13, 1005, 6, 10.00, 10.00, 21.00, 'Fulfilled'),
(14, 1005, 11, 6.00, 4.00, 30.00, 'Partial'),
(15, 1006, 10, 3.00, 3.00, 28.00, 'Fulfilled'),
(16, 1006, 9, 2.00, 2.00, 10.00, 'Fulfilled'),
(17, 1007, 1, 2.00, 2.00, 18.00, 'Fulfilled'),
(18, 1007, 2, 2.00, 0.00, 22.00, 'Unavailable'),
(19, 1007, 8, 1.00, 1.00, 12.00, 'Fulfilled'),
(20, 1008, 5, 4.00, 4.00, 16.00, 'Fulfilled'),
(21, 1008, 10, 2.00, 2.00, 28.00, 'Fulfilled'),
(22, 1008, 12, 2.00, 2.00, 19.00, 'Fulfilled');

-- prep_lists
INSERT INTO prep_lists (
    prep_id, order_id, product_id, quantity_to_prepare, prep_status, assigned_worker, prep_date
) VALUES
(1, 1001, 1, 14.00, 'Completed', 'Maria', '2026-04-01'),
(2, 1001, 2, 8.00, 'Completed', 'Maria', '2026-04-01'),
(3, 1001, 8, 6.00, 'Completed', 'Leo', '2026-04-01'),
(4, 1002, 3, 12.00, 'Completed', 'Jenny', '2026-04-01'),
(5, 1002, 4, 8.00, 'Completed', 'Jenny', '2026-04-01'),
(6, 1002, 10, 7.00, 'Completed', 'Ben', '2026-04-01'),
(7, 1003, 5, 18.00, 'Completed', 'Maria', '2026-04-01'),
(8, 1003, 7, 8.00, 'Completed', 'Maria', '2026-04-01'),
(9, 1004, 2, 10.00, 'Completed', 'Leo', '2026-04-01'),
(10, 1004, 12, 8.00, 'Completed', 'Leo', '2026-04-01'),
(11, 1004, 9, 10.00, 'Completed', 'Jenny', '2026-04-01'),
(12, 1005, 1, 15.00, 'In Progress', 'Ben', '2026-04-01'),
(13, 1005, 6, 10.00, 'In Progress', 'Ben', '2026-04-01'),
(14, 1005, 11, 4.00, 'In Progress', 'Ben', '2026-04-01'),
(15, 1006, 10, 3.00, 'Completed', 'Leo', '2026-04-01'),
(16, 1006, 9, 2.00, 'Completed', 'Leo', '2026-04-01'),
(17, 1007, 1, 2.00, 'Ready', 'Maria', '2026-04-01'),
(18, 1007, 8, 1.00, 'Ready', 'Maria', '2026-04-01'),
(19, 1008, 5, 4.00, 'Pending', 'Jenny', '2026-04-02'),
(20, 1008, 10, 2.00, 'Pending', 'Jenny', '2026-04-02'),
(21, 1008, 12, 2.00, 'Pending', 'Jenny', '2026-04-02');

-- deliveries
INSERT INTO deliveries (
    delivery_id, order_id, scheduled_delivery_time, actual_delivery_time, delivery_status, driver_name, delivery_address
) VALUES
(1, 1001, '2026-04-01 06:30:00', '2026-04-01 06:50:00', 'Delivered Late', 'Carlos', '101 Market St, San Jose, CA'),
(2, 1002, '2026-04-01 07:30:00', '2026-04-01 07:25:00', 'Delivered', 'Amy', '210 Bay Ave, San Francisco, CA'),
(3, 1003, '2026-04-01 05:45:00', '2026-04-01 06:10:00', 'Delivered Late', 'Carlos', '12 Harbor Dock Rd, Oakland, CA'),
(4, 1004, '2026-04-01 08:00:00', '2026-04-01 07:58:00', 'Delivered', 'Amy', '55 Sunrise Blvd, Santa Clara, CA'),
(5, 1005, '2026-04-01 09:15:00', NULL, 'Scheduled', 'Carlos', '88 Evergreen Pkwy, San Jose, CA'),
(6, 1006, '2026-04-01 11:00:00', '2026-04-01 10:50:00', 'Delivered', 'Leo', '44 Monterey Rd, Gilroy, CA'),
(7, 1007, '2026-04-01 12:00:00', '2026-04-01 12:05:00', 'Picked Up', 'Customer Pickup', 'Farm Pickup - Gilroy'),
(8, 1008, '2026-04-02 10:00:00', NULL, 'Ready for Pickup', 'Customer Pickup', 'Farm Pickup - Gilroy');

-- worker_shifts
INSERT INTO worker_shifts (
    shift_id, worker_name, shift_date, task_type, hours_worked, hourly_rate, total_payment, related_order_id, notes
) VALUES
(9001, 'Maria', '2026-04-01', 'Prep', 4.00, 22.00, 88.00, 1001, 'Prepared bok choy and napa cabbage'),
(9002, 'Leo', '2026-04-01', 'Prep', 3.50, 21.00, 73.50, 1001, 'Prepared green onion and staging'),
(9003, 'Jenny', '2026-04-01', 'Prep', 4.50, 22.00, 99.00, 1002, 'Packed choy sum and Chinese broccoli'),
(9004, 'Ben', '2026-04-01', 'Prep', 3.00, 21.00, 63.00, 1002, 'Tomato allocation and packing'),
(9005, 'Maria', '2026-04-01', 'Prep', 5.00, 22.00, 110.00, 1003, 'Prepared spinach and baby bok choy'),
(9006, 'Leo', '2026-04-01', 'Prep', 3.00, 21.00, 63.00, 1004, 'Packed napa and romaine'),
(9007, 'Jenny', '2026-04-01', 'Prep', 2.50, 22.00, 55.00, 1004, 'Bundled cilantro'),
(9008, 'Ben', '2026-04-01', 'Prep', 4.00, 21.00, 84.00, 1005, 'Prepared bok choy water spinach and okra'),
(9009, 'Leo', '2026-04-01', 'Prep', 1.50, 21.00, 31.50, 1006, 'Packed small customer order'),
(9010, 'Maria', '2026-04-01', 'Prep', 1.00, 22.00, 22.00, 1007, 'Prepared pickup order items'),
(9011, 'Carlos', '2026-04-01', 'Delivery', 6.00, 24.00, 144.00, 1001, 'Delivered major market route'),
(9012, 'Amy', '2026-04-01', 'Delivery', 5.50, 24.00, 132.00, 1002, 'Delivered Bay Fresh and Sunrise route'),
(9013, 'Leo', '2026-04-01', 'Delivery', 2.00, 24.00, 48.00, 1006, 'Delivered Gilroy small customer order'),
(9014, 'Jenny', '2026-04-02', 'Prep', 2.00, 22.00, 44.00, 1008, 'Prepared next-day pickup order');



