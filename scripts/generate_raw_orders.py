"""
Generate synthetic raw order data for Yong Sheng operations.

Simulates the messy real-world intake channel: text messages, emails,
spreadsheet lines, phone call notes. Each market type sends orders
in their typical format so downstream parsing has realistic variety.

Fills 8-week window with ~500 orders distributed across market types.
Idempotency handled by check-before-insert (no natural business key exists
because two identical text messages minutes apart are legitimately separate orders).
"""

import random
from datetime import date, timedelta, datetime, time
from db_connection import get_connection


random.seed(43)

START_DATE = date(2025, 4, 1)
NUM_DAYS = 56

SOURCE_CHANNELS_BY_MARKET_TYPE = {
    "restaurant": ["text", "phone", "in_person"],
    "grocery": ["email", "spreadsheet"],
    "wholesale": ["spreadsheet", "email"],
    "distributor": ["email", "spreadsheet"],
    "individual": ["text", "phone"],
}

PRODUCT_MENTIONS = [
    "bok choy", "baby bok choy", "gai lan", "chinese broccoli",
    "napa cabbage", "napa", "shanghai bok choy", "yu choy",
    "chinese chives", "chives", "water spinach", "ong choy",
    "chinese eggplant", "eggplant", "bitter melon", "winter melon",
    "daikon", "lotus root", "shiitake", "enoki",
    "burdock root", "gobo", "long beans", "snow peas", "sugar snap peas",
]

ENTERED_BY_STAFF = ["David Tran", "Wei Chen", "Sofia Garcia"]


def get_customers(cursor):
    """
    Fetch active customers with market type for format-appropriate messages.
    Returns list of dicts.
    """
    cursor.execute("""
        SELECT customer_id, customer_name, market_type
        FROM customers
        WHERE is_active = TRUE
        ORDER BY customer_id
    """)
    rows = cursor.fetchall()
    return [
        {"customer_id": r[0], "customer_name": r[1], "market_type": r[2]}
        for r in rows
    ]


def generate_text_message(customer, products_ordered):
    """
    Generate a messy text-message-style order (restaurants, individuals).
    Casual, lowercase, abbreviated, no punctuation discipline.
    """
    templates = [
        "hi {name} here need {items} for tmr",
        "{items} pls, delivery this week",
        "hey can u send {items} thanks",
        "{name}: {items}",
        "need {items} asap",
    ]
    items_text = ", ".join([f"{qty}lb {product}" for product, qty in products_ordered])
    template = random.choice(templates)
    return template.format(name=customer["customer_name"].lower(), items=items_text)


def generate_email_message(customer, products_ordered):
    """
    Generate a semi-structured email-style order (grocery, distributor).
    Formal salutation, structured item list, signature.
    """
    header = f"Hi Yong Sheng team,\n\nPlease deliver the following to {customer['customer_name']}:\n\n"
    items = "\n".join([f"- {product}: {qty} lbs" for product, qty in products_ordered])
    footer = f"\n\nThanks,\n{customer['customer_name']} Purchasing"
    return header + items + footer


def generate_spreadsheet_line(customer, products_ordered):
    """
    Generate a CSV-like line (wholesale, distributor).
    Structured but different vendors use different column orders in reality.
    """
    lines = []
    for product, qty in products_ordered:
        lines.append(f"{customer['customer_name']},{product},{qty},lbs")
    return "\n".join(lines)


def generate_phone_notes(customer, products_ordered):
    """
    Generate hand-typed phone call notes (restaurants, individuals).
    Bullet-style, brief, transcribed by staff.
    """
    header = f"Phone order from {customer['customer_name']}:\n"
    items = "\n".join([f"* {qty} lb {product}" for product, qty in products_ordered])
    return header + items


def generate_in_person_notes(customer, products_ordered):
    """
    Generate walk-in / in-person order notes (mostly restaurants).
    Quick handwritten-style, minimal formatting.
    """
    items = "; ".join([f"{qty}lb {product}" for product, qty in products_ordered])
    return f"Walk-in: {customer['customer_name']} - {items}"


MESSAGE_GENERATORS = {
    "text": generate_text_message,
    "email": generate_email_message,
    "spreadsheet": generate_spreadsheet_line,
    "phone": generate_phone_notes,
    "in_person": generate_in_person_notes,
}


def generate_order_products():
    """
    Pick 1-6 random products with random quantities for a single order.
    Weighted so most orders have 2-4 items (matches real order composition).
    """
    num_products = random.choices([1, 2, 3, 4, 5, 6], weights=[10, 25, 30, 20, 10, 5])[0]
    selected = random.sample(PRODUCT_MENTIONS, num_products)
    return [(product, random.randint(5, 40)) for product in selected]


def generate_received_timestamp(order_date):
    """
    Generate a realistic time-of-day for order receipt.
    Weighted toward business hours 8am-8pm, peak in mid-morning.
    """
    hour = random.choices(
        range(6, 22),
        weights=[2, 5, 10, 12, 10, 8, 6, 8, 10, 8, 6, 4, 3, 2, 2, 2]
    )[0]
    minute = random.randint(0, 59)
    return datetime.combine(order_date, time(hour=hour, minute=minute))


def generate_raw_orders(customers, target_total=500):
    """
    Build the full list of raw order records to insert.
    
    Distributes orders across customers weighted by market type
    (restaurants and grocery order more frequently than individuals).
    Randomly spread across the 8-week window.
    """
    type_weights = {
        "restaurant": 3.0,
        "grocery": 2.5,
        "wholesale": 2.0,
        "distributor": 1.5,
        "individual": 0.5,
    }
    
    weighted_customers = []
    for customer in customers:
        weight = type_weights.get(customer["market_type"], 1.0)
        weighted_customers.extend([customer] * int(weight * 10))
    
    records = []
    for _ in range(target_total):
        customer = random.choice(weighted_customers)
        day_offset = random.randint(0, NUM_DAYS - 1)
        order_date = START_DATE + timedelta(days=day_offset)
        received_timestamp = generate_received_timestamp(order_date)
        
        allowed_channels = SOURCE_CHANNELS_BY_MARKET_TYPE.get(
            customer["market_type"], 
            ["email"]
        )
        source_channel = random.choice(allowed_channels)
        
        products_ordered = generate_order_products()
        
        message_generator = MESSAGE_GENERATORS[source_channel]
        order_text = message_generator(customer, products_ordered)
        
        entered_by = random.choice(ENTERED_BY_STAFF) if source_channel in ("phone", "in_person") else None
        
        records.append({
            "customer_name_raw": customer["customer_name"],
            "order_text": order_text,
            "received_timestamp": received_timestamp,
            "source_channel": source_channel,
            "entered_by": entered_by,
        })
    
    return records


def check_existing_count(cursor):
    """Check how many raw orders already exist. Used for idempotency."""
    cursor.execute("SELECT COUNT(*) FROM incoming_orders_raw")
    return cursor.fetchone()[0]


def insert_raw_orders(cursor, records):
    """
    Insert raw order records.
    
    No ON CONFLICT here because raw orders have no natural business key —
    duplicate text messages are legitimately separate orders in reality.
    Idempotency handled by check_existing_count in main().
    """
    for record in records:
        cursor.execute("""
            INSERT INTO incoming_orders_raw 
                (customer_name_raw, order_text, received_timestamp, source_channel, entered_by)
            VALUES 
                (%s, %s, %s, %s, %s)
        """, (
            record["customer_name_raw"],
            record["order_text"],
            record["received_timestamp"],
            record["source_channel"],
            record["entered_by"],
        ))
    return len(records)


def main():
    """Orchestrate raw order generation with idempotency check and transaction management."""
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        existing_count = check_existing_count(cursor)
        if existing_count > 0:
            print(f"Table already has {existing_count} raw orders.")
            print("Skipping generation. To regenerate, run:")
            print("  TRUNCATE incoming_orders_raw RESTART IDENTITY;")
            return
        
        print("Fetching active customers...")
        customers = get_customers(cursor)
        print(f"  Found {len(customers)} active customers.")
        
        print(f"\nGenerating raw order records...")
        print(f"  Window: {START_DATE} to {START_DATE + timedelta(days=NUM_DAYS-1)}")
        records = generate_raw_orders(customers, target_total=500)
        print(f"  Generated {len(records)} raw order records.")
        
        print(f"\nInserting into incoming_orders_raw...")
        inserted = insert_raw_orders(cursor, records)
        
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