"""
Generate customer records for Farm Operations Analytics.

Creates 20 realistic customers covering Bay Area Asian produce buyers:
restaurants, grocery stores, wholesale buyers, distributors, and individuals.
Uses Faker for randomization with domain-specific name generation.

Idempotent: safe to re-run. Uses ON CONFLICT to update existing customers.
"""

import random
from datetime import date, timedelta
from faker import Faker

from db_connection import get_connection


# Initialize Faker
fake = Faker()
# Seed for reproducibility — same data every run during development
Faker.seed(42)
random.seed(42)


# =========================================
# DOMAIN-SPECIFIC NAME COMPONENTS
# Reflects realistic Bay Area Asian produce distribution context
# =========================================

RESTAURANT_PREFIXES = [
    "Golden", "Lucky", "Happy", "Phoenix", "Dragon", "Jade",
    "Lotus", "Imperial", "New", "Little", "Great", "Royal"
]

RESTAURANT_SUFFIXES = [
    "Garden", "Palace", "Restaurant", "Kitchen", "House",
    "Dim Sum", "BBQ", "Noodle Bar", "Hot Pot", "Wok"
]

GROCERY_PREFIXES = [
    "Bay", "Sunset", "Mission", "Pacific", "Asian", "Oriental",
    "99 Ranch", "Marina", "Lucky", "Mei Mei"
]

GROCERY_SUFFIXES = [
    "Market", "Grocery", "Supermarket", "Fresh", "Foods"
]

WHOLESALE_NAMES = [
    "Pacific Produce Distributors",
    "Bay Area Fresh Wholesale",
    "Golden State Produce Co",
    "Asian Foods Wholesale",
    "South Bay Distribution"
]

REGIONS = [
    "San Francisco", "Oakland", "San Jose", "Daly City",
    "Fremont", "Sunnyvale", "Santa Clara", "Milpitas",
    "Hayward", "Burlingame"
]


# =========================================
# NAME GENERATORS
# =========================================

def generate_restaurant_name():
    """Generate realistic Chinese-American restaurant name."""
    return f"{random.choice(RESTAURANT_PREFIXES)} {random.choice(RESTAURANT_SUFFIXES)}"


def generate_grocery_name():
    """Generate realistic Asian grocery store name."""
    return f"{random.choice(GROCERY_PREFIXES)} {random.choice(GROCERY_SUFFIXES)}"


def generate_wholesale_name():
    """Generate wholesale distributor name from preset list."""
    return random.choice(WHOLESALE_NAMES)


def generate_individual_name():
    """Generate a realistic individual customer name using Faker."""
    return fake.name()


# =========================================
# CUSTOMER RECORD GENERATION
# =========================================

def generate_customer_records(num_customers=20):
    """
    Generate a list of customer dictionaries with realistic
    distribution across market types.
    
    Args:
        num_customers: Number of customer records to generate (default 20)
    
    Returns:
        List of customer dictionaries.
    """
    customers = []
    
    # Track used names to avoid duplicates within this batch
    used_names = set()
    
    # Date range: customers signed up in the last 2 years
    earliest_signup = date.today() - timedelta(days=730)
    latest_signup = date.today() - timedelta(days=30)
    
    for i in range(num_customers):
        # Weighted random market type selection
        market_type = random.choices(
            ['restaurant', 'grocery', 'wholesale', 'distributor', 'individual'],
            weights=[40, 25, 20, 10, 5],
            k=1
        )[0]
        
        # Generate name based on market type
        # Loop until we get a unique name (avoid duplicates)
        while True:
            if market_type == 'restaurant':
                name = generate_restaurant_name()
            elif market_type == 'grocery':
                name = generate_grocery_name()
            elif market_type in ('wholesale', 'distributor'):
                name = generate_wholesale_name()
            else:  # individual
                name = generate_individual_name()
            
            if name not in used_names:
                used_names.add(name)
                break
        
        # Generate other fields
        signup_date = fake.date_between(
            start_date=earliest_signup,
            end_date=latest_signup
        )
        region = random.choice(REGIONS)
        
        # 90% of customers are active, 10% are inactive (soft-deleted)
        is_active = random.random() < 0.90
        
        customers.append({
            "customer_name": name,
            "market_type": market_type,
            "region": region,
            "signup_date": signup_date,
            "is_active": is_active,
        })
    
    return customers


# =========================================
# DATABASE INSERT
# =========================================

def insert_customers(customers):
    """
    Insert customer records into the database.
    
    Idempotent: uses ON CONFLICT to update existing customers rather than
    fail or create duplicates. Safe to re-run after data changes.
    
    Returns:
        tuple: (inserted_count, updated_count)
    """
    conn = get_connection()
    cursor = conn.cursor()
    
    insert_sql = """
        INSERT INTO customers (
            customer_name, market_type, region, signup_date, is_active
        ) VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT (customer_name) DO UPDATE SET
            market_type = EXCLUDED.market_type,
            region = EXCLUDED.region,
            signup_date = EXCLUDED.signup_date,
            is_active = EXCLUDED.is_active,
            updated_at = CURRENT_TIMESTAMP
        RETURNING customer_id, customer_name, (xmax = 0) AS was_inserted;
    """
    
    inserted_count = 0
    updated_count = 0
    
    for customer in customers:
        cursor.execute(insert_sql, (
            customer["customer_name"],
            customer["market_type"],
            customer["region"],
            customer["signup_date"],
            customer["is_active"],
        ))
        result = cursor.fetchone()
        customer_id, customer_name, was_inserted = result
        
        if was_inserted:
            print(f"Inserted customer {customer_id}: {customer_name} ({customer['market_type']})")
            inserted_count += 1
        else:
            print(f"Updated customer {customer_id}: {customer_name}")
            updated_count += 1
    
    conn.commit()
    cursor.close()
    conn.close()
    
    return inserted_count, updated_count


# =========================================
# MAIN
# =========================================

if __name__ == "__main__":
    print("Generating customer records...")
    customers = generate_customer_records(num_customers=20)
    print(f"Generated {len(customers)} customer records")
    
    # Show distribution summary before inserting
    market_counts = {}
    for c in customers:
        market_counts[c['market_type']] = market_counts.get(c['market_type'], 0) + 1
    print(f"Distribution: {market_counts}")
    
    print("\nLoading to database...")
    inserted, updated = insert_customers(customers)
    
    print(f"\nSuccess. {inserted} inserted, {updated} updated.")