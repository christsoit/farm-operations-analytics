"""
Generate cleaned orders by parsing incoming_orders_raw records.

Simulates the raw-to-cleaned staging pattern: reads messy raw records,
matches customers via fuzzy name lookup, derives structured fields
(order_date, delivery_date, status, item counts, value), and writes
to orders_cleaned with FK lineage back to the raw record.

Not every raw record gets cleaned successfully — some end up with
cleaning_status='needs_review' or 'incomplete' to reflect real parsing
challenges. This makes the data honest for downstream analytics.

Idempotency handled by check-before-insert; regenerating requires
TRUNCATE orders_cleaned first.
"""

import random
from datetime import timedelta
from db_connection import get_connection


random.seed(44)

ORDER_STATUSES = ["pending", "confirmed", "fulfilled", "partial", "shorted"]
STATUS_WEIGHTS = [10, 20, 55, 10, 5]

CLEANING_STATUSES = ["clean", "needs_review", "incomplete", "rejected"]
CLEANING_WEIGHTS = [80, 12, 5, 3]


def get_customer_lookup(cursor):
    """
    Build a lookup dict of customer_name -> customer_id.
    Used to resolve raw customer_name_raw to a valid FK.
    """
    cursor.execute("""
        SELECT customer_id, customer_name
        FROM customers
        WHERE is_active = TRUE
    """)
    rows = cursor.fetchall()
    return {row[1]: row[0] for row in rows}


def get_raw_orders(cursor):
    """
    Fetch all raw orders that haven't been cleaned yet.
    Returns list of dicts ready for parsing simulation.
    """
    cursor.execute("""
        SELECT raw_order_id, customer_name_raw, received_timestamp, source_channel
        FROM incoming_orders_raw
        WHERE raw_order_id NOT IN (
            SELECT raw_order_id FROM orders_cleaned WHERE raw_order_id IS NOT NULL
        )
        ORDER BY raw_order_id
    """)
    rows = cursor.fetchall()
    return [
        {
            "raw_order_id": r[0],
            "customer_name_raw": r[1],
            "received_timestamp": r[2],
            "source_channel": r[3],
        }
        for r in rows
    ]


def simulate_parsing(raw_order, customer_lookup):
    """
    Simulate parsing a raw order into structured cleaned form.
    
    In production, this would use regex, NLP, or LLM parsing on order_text.
    Here we simulate the outcomes: successful parses get 'clean' status,
    some get 'needs_review' with realistic issues, a few get 'rejected'.
    
    Returns a dict ready for insert, or None if the record should be skipped.
    """
    customer_id = customer_lookup.get(raw_order["customer_name_raw"])
    if customer_id is None:
        return None
    
    cleaning_status = random.choices(CLEANING_STATUSES, weights=CLEANING_WEIGHTS)[0]
    
    if cleaning_status == "rejected":
        return None
    
    order_date = raw_order["received_timestamp"].date()
    
    delivery_offset_days = random.choices([0, 1, 2, 3, 7], weights=[10, 40, 25, 15, 10])[0]
    requested_delivery_date = order_date + timedelta(days=delivery_offset_days)
    
    order_status = random.choices(ORDER_STATUSES, weights=STATUS_WEIGHTS)[0]
    
    if cleaning_status == "incomplete":
        total_items = None
        total_value = None
        notes = "Missing item details in original message; requires customer follow-up"
    elif cleaning_status == "needs_review":
        total_items = random.randint(2, 6)
        total_value = round(random.uniform(50, 400), 2)
        notes = random.choice([
            "Ambiguous quantity phrasing; needs verification",
            "Customer name matched via partial string; confirm identity",
            "Delivery date interpretation uncertain",
        ])
    else:
        total_items = random.randint(1, 8)
        total_value = round(random.uniform(30, 600), 2)
        notes = None
    
    return {
        "raw_order_id": raw_order["raw_order_id"],
        "customer_id": customer_id,
        "order_date": order_date,
        "requested_delivery_date": requested_delivery_date,
        "order_status": order_status,
        "cleaning_status": cleaning_status,
        "total_items": total_items,
        "total_value": total_value,
        "notes": notes,
    }


def insert_cleaned_orders(cursor, records):
    """
    Insert cleaned order records with FK lineage back to raw.
    Returns count of inserts.
    """
    for record in records:
        cursor.execute("""
            INSERT INTO orders_cleaned 
                (raw_order_id, customer_id, order_date, requested_delivery_date,
                 order_status, cleaning_status, total_items, total_value, notes)
            VALUES 
                (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            record["raw_order_id"],
            record["customer_id"],
            record["order_date"],
            record["requested_delivery_date"],
            record["order_status"],
            record["cleaning_status"],
            record["total_items"],
            record["total_value"],
            record["notes"],
        ))
    return len(records)


def main():
    """Orchestrate raw-to-cleaned parsing with FK lineage and transaction management."""
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        print("Building customer name lookup...")
        customer_lookup = get_customer_lookup(cursor)
        print(f"  Loaded {len(customer_lookup)} active customer name mappings.")
        
        print("\nFetching unprocessed raw orders...")
        raw_orders = get_raw_orders(cursor)
        print(f"  Found {len(raw_orders)} raw orders to parse.")
        
        if not raw_orders:
            print("\nNothing to do — all raw orders already have cleaned versions.")
            return
        
        print("\nSimulating parsing to cleaned records...")
        cleaned_records = []
        rejected_or_skipped = 0
        for raw in raw_orders:
            parsed = simulate_parsing(raw, customer_lookup)
            if parsed is None:
                rejected_or_skipped += 1
            else:
                cleaned_records.append(parsed)
        
        print(f"  Successfully parsed: {len(cleaned_records)}")
        print(f"  Rejected or unmatched: {rejected_or_skipped}")
        
        status_counts = {}
        for record in cleaned_records:
            status_counts[record["cleaning_status"]] = status_counts.get(record["cleaning_status"], 0) + 1
        print(f"  Cleaning status breakdown: {status_counts}")
        
        print("\nInserting into orders_cleaned...")
        inserted = insert_cleaned_orders(cursor, cleaned_records)
        
        conn.commit()
        print(f"\nSuccess!")
        print(f"  Records inserted: {inserted}")
        
    except Exception as e:
        conn.rollback()
        print(f"\nError: {e}")
        raise
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()