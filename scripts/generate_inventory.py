"""
Generate inventory snapshot data for Yong Sheng operations.

Creates daily inventory snapshots for each product across 8 weeks,
simulating realistic stock levels that decrease with sales and replenish 
with supplier deliveries.

Idempotent: safe to re-run; uses ON CONFLICT to update existing snapshots.
Grain enforced by composite UNIQUE on (product_id, inventory_date, warehouse_location).
"""

import random
from datetime import date, timedelta
from db_connection import get_connection


random.seed(42)

START_DATE = date(2025, 4, 1)
NUM_DAYS = 56
LOCATIONS = ["cooler", "warehouse", "display"]

BASE_QUANTITY_BY_UNIT = {
    "lbs": (50, 200),
    "heads": (30, 100),
    "cases": (10, 30),
    "bunches": (20, 80),
}


def get_products(cursor):
    """
    Fetch active products with unit of measure.
    Excludes soft-deleted products so they don't get new snapshots.
    """
    cursor.execute("""
        SELECT product_id, product_name, unit
        FROM products
        WHERE is_active = TRUE
        ORDER BY product_id
    """)
    rows = cursor.fetchall()
    return [
        {"product_id": r[0], "product_name": r[1], "unit": r[2]}
        for r in rows
    ]


def generate_daily_quantity(base_min, base_max, day_of_week):
    """
    Generate daily inventory quantity with business-driven variance:
    delivery days (Mon/Thu) boost stock, Sundays deplete after weekend rush.
    """
    base = random.randint(base_min, base_max)
    if day_of_week in (0, 3):
        base = int(base * random.uniform(1.1, 1.3))
    if day_of_week == 6:
        base = int(base * random.uniform(0.5, 0.8))
    return max(base, 1)


def generate_inventory_records(products):
    """
    Build inventory snapshot records: one per product per day per location.
    Not all products live in all locations — assign 1-2 locations per product.
    """
    records = []
    for product in products:
        num_locations = random.choice([1, 2])
        product_locations = random.sample(LOCATIONS, num_locations)
        unit = product["unit"]
        base_range = BASE_QUANTITY_BY_UNIT.get(unit, (10, 50))
        
        for day_offset in range(NUM_DAYS):
            inventory_date = START_DATE + timedelta(days=day_offset)
            day_of_week = inventory_date.weekday()
            
            for location in product_locations:
                quantity = generate_daily_quantity(base_range[0], base_range[1], day_of_week)
                records.append({
                    "product_id": product["product_id"],
                    "inventory_date": inventory_date,
                    "available_quantity": quantity,
                    "warehouse_location": location,
                })
    return records


def insert_inventory(cursor, records):
    """
    Idempotent upsert of inventory records.
    ON CONFLICT updates on grain (product_id, inventory_date, warehouse_location).
    Returns (inserted_count, updated_count).
    """
    inserted = 0
    updated = 0
    for record in records:
        cursor.execute("""
            INSERT INTO inventory 
                (product_id, inventory_date, available_quantity, warehouse_location)
            VALUES 
                (%s, %s, %s, %s)
            ON CONFLICT (product_id, inventory_date, warehouse_location) 
            DO UPDATE SET
                available_quantity = EXCLUDED.available_quantity,
                updated_at = CURRENT_TIMESTAMP
            RETURNING (xmax = 0) AS was_inserted
        """, (
            record["product_id"],
            record["inventory_date"],
            record["available_quantity"],
            record["warehouse_location"],
        ))
        was_inserted = cursor.fetchone()[0]
        if was_inserted:
            inserted += 1
        else:
            updated += 1
    return inserted, updated


def main():
    """Orchestrate the inventory load with transaction management."""
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        print("Fetching active products...")
        products = get_products(cursor)
        print(f"  Found {len(products)} active products.")
        
        print(f"\nGenerating inventory snapshots...")
        print(f"  Window: {START_DATE} to {START_DATE + timedelta(days=NUM_DAYS-1)}")
        records = generate_inventory_records(products)
        print(f"  Generated {len(records)} inventory records.")
        
        print(f"\nInserting into inventory table...")
        inserted, updated = insert_inventory(cursor, records)
        
        conn.commit()
        print(f"\nSuccess!")
        print(f"  New records inserted: {inserted}")
        print(f"  Existing records updated: {updated}")
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