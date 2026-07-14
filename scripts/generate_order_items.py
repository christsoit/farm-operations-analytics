"""
Generate order line items for cleaned orders.

Simulates the line-item detail that would be extracted from parsing
raw order text: for each cleaned order, create 1-6 items with
requested/confirmed quantities and unit prices.

Line items respect the parent order's cleaning_status:
- 'clean' orders get full items with confirmed quantities
- 'needs_review' orders may have some items pending
- 'incomplete' orders are skipped (parent has NULL total_items anyway)

Idempotency via UNIQUE grain (order_id, product_id): safe to re-run,
skips orders that already have items.
"""

import random
from db_connection import get_connection


random.seed(45)

ITEM_STATUSES = ["pending", "confirmed", "fulfilled", "partial", "shorted"]


def get_products_by_id(cursor):
    """
    Build lookup: product_id -> {name, unit, price}.
    Used to assign realistic unit prices and units to line items.
    """
    cursor.execute("""
        SELECT product_id, product_name, unit, standard_price
        FROM products
        WHERE is_active = TRUE
    """)
    rows = cursor.fetchall()
    return {
        row[0]: {"name": row[1], "unit": row[2], "price": float(row[3])}
        for row in rows
    }


def get_orders_needing_items(cursor):
    """
    Fetch cleaned orders that need line items generated.
    Skip 'incomplete' orders (parent has NULL total_items).
    Skip orders that already have items in order_items table.
    """
    cursor.execute("""
        SELECT oc.order_id, oc.cleaning_status, oc.order_status, oc.total_items
        FROM orders_cleaned oc
        WHERE oc.cleaning_status IN ('clean', 'needs_review')
          AND oc.total_items IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM order_items oi WHERE oi.order_id = oc.order_id
          )
        ORDER BY oc.order_id
    """)
    rows = cursor.fetchall()
    return [
        {
            "order_id": r[0],
            "cleaning_status": r[1],
            "order_status": r[2],
            "total_items": r[3],
        }
        for r in rows
    ]


def determine_item_status(order_status, cleaning_status):
    """
    Line item status derives from parent order status.
    'needs_review' orders have some items still pending confirmation.
    """
    if cleaning_status == "needs_review":
        return random.choices(
            ["pending", "confirmed", "fulfilled"],
            weights=[30, 40, 30]
        )[0]
    
    status_map = {
        "pending": ["pending"],
        "confirmed": ["confirmed", "confirmed", "pending"],
        "fulfilled": ["fulfilled"],
        "partial": ["fulfilled", "shorted", "partial"],
        "shorted": ["shorted", "partial", "fulfilled"],
    }
    return random.choice(status_map.get(order_status, ["pending"]))


def generate_confirmed_quantity(requested, item_status):
    """
    Confirmed quantity depends on line item status.
    Real business logic: pending items have NULL confirmed_quantity;
    fulfilled means requested was met exactly; partial/shorted means less.
    """
    if item_status == "pending":
        return None
    if item_status == "fulfilled":
        return requested
    if item_status == "confirmed":
        return requested
    if item_status == "partial":
        return round(requested * random.uniform(0.5, 0.9), 2)
    if item_status == "shorted":
        return round(requested * random.uniform(0.1, 0.5), 2)
    return requested


def generate_items_for_order(order, product_lookup):
    """
    Generate line items for a single cleaned order.
    
    Number of items comes from parent's total_items count.
    Products picked randomly without replacement (no duplicate SKU per order).
    Quantities and unit prices sampled from realistic ranges per product.
    """
    num_items = order["total_items"]
    product_ids = list(product_lookup.keys())
    
    if num_items > len(product_ids):
        num_items = len(product_ids)
    
    selected_product_ids = random.sample(product_ids, num_items)
    
    items = []
    for product_id in selected_product_ids:
        product = product_lookup[product_id]
        
        base_price = product["price"]
        unit_price = round(base_price * random.uniform(0.9, 1.15), 2)
        
        requested_quantity = round(random.uniform(5, 40), 2)
        
        item_status = determine_item_status(
            order["order_status"], 
            order["cleaning_status"]
        )
        
        confirmed_quantity = generate_confirmed_quantity(requested_quantity, item_status)
        
        items.append({
            "order_id": order["order_id"],
            "product_id": product_id,
            "requested_quantity": requested_quantity,
            "confirmed_quantity": confirmed_quantity,
            "unit_price": unit_price,
            "item_status": item_status,
        })
    
    return items


def insert_order_items(cursor, items):
    """
    Insert order items with idempotency via ON CONFLICT.
    Grain: (order_id, product_id) is UNIQUE.
    Returns (inserted_count, updated_count).
    """
    inserted = 0
    updated = 0
    for item in items:
        cursor.execute("""
            INSERT INTO order_items 
                (order_id, product_id, requested_quantity, confirmed_quantity,
                 unit_price, item_status)
            VALUES 
                (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (order_id, product_id) 
            DO UPDATE SET
                requested_quantity = EXCLUDED.requested_quantity,
                confirmed_quantity = EXCLUDED.confirmed_quantity,
                unit_price = EXCLUDED.unit_price,
                item_status = EXCLUDED.item_status,
                updated_at = CURRENT_TIMESTAMP
            RETURNING (xmax = 0) AS was_inserted
        """, (
            item["order_id"],
            item["product_id"],
            item["requested_quantity"],
            item["confirmed_quantity"],
            item["unit_price"],
            item["item_status"],
        ))
        was_inserted = cursor.fetchone()[0]
        if was_inserted:
            inserted += 1
        else:
            updated += 1
    return inserted, updated


def main():
    """Orchestrate line item generation for cleaned orders with transaction management."""
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        print("Building product lookup...")
        product_lookup = get_products_by_id(cursor)
        print(f"  Loaded {len(product_lookup)} active products with pricing.")
        
        print("\nFetching orders needing items...")
        orders = get_orders_needing_items(cursor)
        print(f"  Found {len(orders)} orders to process.")
        
        if not orders:
            print("\nNothing to do — all orders already have items or are 'incomplete'.")
            return
        
        print("\nGenerating line items...")
        all_items = []
        for order in orders:
            items = generate_items_for_order(order, product_lookup)
            all_items.extend(items)
        print(f"  Generated {len(all_items)} line items across {len(orders)} orders.")
        
        status_counts = {}
        for item in all_items:
            status_counts[item["item_status"]] = status_counts.get(item["item_status"], 0) + 1
        print(f"  Item status breakdown: {status_counts}")
        
        print("\nInserting into order_items...")
        inserted, updated = insert_order_items(cursor, all_items)
        
        conn.commit()
        print(f"\nSuccess!")
        print(f"  New items inserted: {inserted}")
        print(f"  Existing items updated: {updated}")
        print(f"  Total: {inserted + updated}")
        
    except Exception as e:
        conn.rollback()
        print(f"\nError: {e}")
        raise
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()