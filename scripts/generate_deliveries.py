"""
Generate delivery events for cleaned orders.

Simulates the physical fulfillment step: each delivered order gets exactly
one delivery record with driver assignment, scheduled/actual times, address,
and status. Only orders with fulfilled/partial/shorted status get deliveries;
pending/confirmed orders haven't left the warehouse yet.

On-time performance is realistic:
  75% on-time (actual matches scheduled)
  15% 1-day late
  8%  2+ days late
  2%  failed (actual_delivery_time NULL, status='failed')

Idempotency via UNIQUE(order_id): safe to re-run, skips orders that
already have deliveries.
"""

import random
from datetime import datetime, time, timedelta
from db_connection import get_connection


random.seed(46)

DELIVERY_STATUSES = ["delivered", "delivered", "delivered", "failed", "cancelled"]

STREET_NAMES = [
    "Market St", "Mission St", "Van Ness Ave", "Geary Blvd", "Broadway",
    "Grand Ave", "Franklin St", "Webster St", "Alameda Ave", "Clement St",
    "Irving St", "Judah St", "Ocean Ave", "El Camino Real", "First St",
    "Almaden Blvd", "Stevens Creek Blvd", "Sunnyvale Ave", "Wolfe Rd",
    "Foothill Blvd", "Milpitas Blvd", "Berryessa Rd", "Story Rd",
]

CITIES_BY_REGION = {
    "SF": ["San Francisco"],
    "East Bay": ["Oakland", "Berkeley", "Alameda", "Fremont", "Hayward"],
    "South Bay": ["San Jose", "Sunnyvale", "Mountain View", "Santa Clara", "Milpitas"],
    "Peninsula": ["San Mateo", "Redwood City", "Palo Alto", "Daly City"],
    "North Bay": ["San Rafael", "Novato", "Mill Valley"],
}


def get_deliverable_orders(cursor):
    """
    Fetch cleaned orders that need delivery records.
    Only orders with fulfilled/partial/shorted have been physically delivered.
    Skip orders that already have deliveries (idempotency).
    """
    cursor.execute("""
        SELECT 
            oc.order_id, 
            oc.order_status, 
            oc.requested_delivery_date,
            c.customer_name,
            c.region
        FROM orders_cleaned oc
        JOIN customers c ON oc.customer_id = c.customer_id
        WHERE oc.order_status IN ('fulfilled', 'partial', 'shorted')
          AND oc.requested_delivery_date IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM deliveries d WHERE d.order_id = oc.order_id
          )
        ORDER BY oc.order_id
    """)
    rows = cursor.fetchall()
    return [
        {
            "order_id": r[0],
            "order_status": r[1],
            "requested_delivery_date": r[2],
            "customer_name": r[3],
            "region": r[4],
        }
        for r in rows
    ]


def get_active_drivers(cursor):
    """
    Fetch workers who can deliver: drivers and multi_role only.
    Prep workers stay in warehouse; supervisors don't drive.
    """
    cursor.execute("""
        SELECT worker_id, worker_name, role
        FROM workers
        WHERE is_active = TRUE
          AND role IN ('driver', 'multi_role')
        ORDER BY worker_id
    """)
    rows = cursor.fetchall()
    return [
        {"worker_id": r[0], "worker_name": r[1], "role": r[2]}
        for r in rows
    ]


def generate_delivery_address(customer_name, region):
    """
    Build a synthetic Bay Area delivery address.
    Format: 'Customer Name, 1234 Market St, San Francisco, CA'
    """
    street_number = random.randint(100, 9999)
    street = random.choice(STREET_NAMES)
    cities = CITIES_BY_REGION.get(region, ["San Jose"])
    city = random.choice(cities)
    return f"{customer_name}, {street_number} {street}, {city}, CA"


def generate_scheduled_time(delivery_date):
    """
    Scheduled delivery time is during business hours.
    Delivery slots weighted toward morning (produce arrives fresh).
    """
    hour = random.choices(
        [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        weights=[10, 20, 25, 15, 10, 8, 5, 3, 2, 2]
    )[0]
    minute = random.choice([0, 15, 30, 45])
    return datetime.combine(delivery_date, time(hour=hour, minute=minute))


def determine_delivery_outcome():
    """
    Pick delivery outcome with realistic distribution:
      75% on-time, 15% 1-day late, 8% 2+ days late, 2% failed
    Returns tuple: (status, days_late_or_None)
    """
    outcome = random.choices(
        ["on_time", "1_day_late", "multi_day_late", "failed"],
        weights=[75, 15, 8, 2]
    )[0]
    
    if outcome == "on_time":
        return ("delivered", 0)
    if outcome == "1_day_late":
        return ("delivered", 1)
    if outcome == "multi_day_late":
        return ("delivered", random.randint(2, 5))
    return ("failed", None)


def generate_delivery(order, drivers):
    """
    Build a single delivery record for a deliverable order.
    Assigns driver, scheduled/actual times, address, and status.
    """
    scheduled_time = generate_scheduled_time(order["requested_delivery_date"])
    status, days_late = determine_delivery_outcome()
    
    if status == "failed":
        actual_time = None
        driver = random.choice(drivers)
    else:
        actual_date = order["requested_delivery_date"] + timedelta(days=days_late)
        actual_hour_shift = random.randint(-2, 3)
        actual_time = scheduled_time.replace(
            hour=max(6, min(18, scheduled_time.hour + actual_hour_shift))
        )
        actual_time = actual_time + timedelta(days=days_late)
        driver = random.choice(drivers)
    
    address = generate_delivery_address(order["customer_name"], order["region"])
    
    return {
        "order_id": order["order_id"],
        "scheduled_delivery_time": scheduled_time,
        "actual_delivery_time": actual_time,
        "delivery_status": status,
        "driver_worker_id": driver["worker_id"],
        "delivery_address": address,
    }


def insert_deliveries(cursor, deliveries):
    """
    Insert delivery records.
    UNIQUE(order_id) at the DB level guarantees one delivery per order.
    Returns count inserted.
    """
    for delivery in deliveries:
        cursor.execute("""
            INSERT INTO deliveries 
                (order_id, scheduled_delivery_time, actual_delivery_time,
                 delivery_status, driver_worker_id, delivery_address)
            VALUES 
                (%s, %s, %s, %s, %s, %s)
        """, (
            delivery["order_id"],
            delivery["scheduled_delivery_time"],
            delivery["actual_delivery_time"],
            delivery["delivery_status"],
            delivery["driver_worker_id"],
            delivery["delivery_address"],
        ))
    return len(deliveries)


def main():
    """Orchestrate delivery generation with driver assignment and transaction management."""
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        print("Fetching active drivers...")
        drivers = get_active_drivers(cursor)
        print(f"  Found {len(drivers)} active delivery-capable workers:")
        for driver in drivers:
            print(f"    {driver['worker_name']} ({driver['role']})")
        
        if not drivers:
            print("\nERROR: No active drivers or multi_role workers found!")
            print("Ensure workers table has at least one active driver.")
            return
        
        print("\nFetching orders needing deliveries...")
        orders = get_deliverable_orders(cursor)
        print(f"  Found {len(orders)} deliverable orders to process.")
        
        if not orders:
            print("\nNothing to do — all deliverable orders already have delivery records.")
            return
        
        print("\nGenerating delivery records...")
        deliveries = [generate_delivery(order, drivers) for order in orders]
        
        status_counts = {}
        for d in deliveries:
            status_counts[d["delivery_status"]] = status_counts.get(d["delivery_status"], 0) + 1
        print(f"  Status breakdown: {status_counts}")
        
        driver_counts = {}
        for d in deliveries:
            driver_id = d["driver_worker_id"]
            driver_name = next(dr["worker_name"] for dr in drivers if dr["worker_id"] == driver_id)
            driver_counts[driver_name] = driver_counts.get(driver_name, 0) + 1
        print(f"  Driver assignment: {driver_counts}")
        
        print("\nInserting into deliveries...")
        inserted = insert_deliveries(cursor, deliveries)
        
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