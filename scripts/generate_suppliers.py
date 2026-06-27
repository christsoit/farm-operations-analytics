"""
Generate supplier records for Farm Operations Analytics.

Creates 8 realistic suppliers for the produce distribution business.
Mix of own-farm sources, external farms, and wholesale market suppliers.
"""

from db_connection import get_connection


def generate_supplier_records():
    """
    Returns a list of supplier dictionaries.
    
    Hand-crafted for realism because suppliers are a small dimension
    where realistic Bay Area produce distribution context matters.
    """
    suppliers = [
        {
            "supplier_name": "Yong Sheng Farm",
            "supplier_region": "Gilroy",
            "supplier_type": "own_farm",
            "is_local": True,
            "is_active": True,
        },
        {
            "supplier_name": "Salinas Valley Greens",
            "supplier_region": "Salinas",
            "supplier_type": "external_farm",
            "is_local": True,
            "is_active": True,
        },
        {
            "supplier_name": "Watsonville Organic Co-op",
            "supplier_region": "Watsonville",
            "supplier_type": "external_farm",
            "is_local": True,
            "is_active": True,
        },
        {
            "supplier_name": "Central Valley Produce",
            "supplier_region": "Fresno",
            "supplier_type": "external_farm",
            "is_local": False,
            "is_active": True,
        },
        {
            "supplier_name": "Bay Area Wholesale Market",
            "supplier_region": "San Francisco",
            "supplier_type": "wholesale_market",
            "is_local": True,
            "is_active": True,
        },
        {
            "supplier_name": "Oakland Asian Produce",
            "supplier_region": "Oakland",
            "supplier_type": "distributor",
            "is_local": True,
            "is_active": True,
        },
        {
            "supplier_name": "Sunshine Imports",
            "supplier_region": "Los Angeles",
            "supplier_type": "distributor",
            "is_local": False,
            "is_active": True,
        },
        {
            "supplier_name": "Half Moon Bay Farms",
            "supplier_region": "Half Moon Bay",
            "supplier_type": "external_farm",
            "is_local": True,
            "is_active": False,  # Inactive supplier — demonstrates soft-delete
        },
    ]
    return suppliers


def insert_suppliers(suppliers):
    """
    Insert supplier records into the database.
    
    Idempotent: uses ON CONFLICT to update existing suppliers rather than 
    fail or create duplicates. Safe to re-run after data changes.
    """
    conn = get_connection()
    cursor = conn.cursor()
    
    insert_sql = """
        INSERT INTO suppliers (
            supplier_name, supplier_region, supplier_type, is_local, is_active
        ) VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT (supplier_name) DO UPDATE SET
            supplier_region = EXCLUDED.supplier_region,
            supplier_type = EXCLUDED.supplier_type,
            is_local = EXCLUDED.is_local,
            is_active = EXCLUDED.is_active,
            updated_at = CURRENT_TIMESTAMP
        RETURNING supplier_id, supplier_name, (xmax = 0) AS was_inserted;
    """
    
    inserted_count = 0
    updated_count = 0
    
    for supplier in suppliers:
        cursor.execute(insert_sql, (
            supplier["supplier_name"],
            supplier["supplier_region"],
            supplier["supplier_type"],
            supplier["is_local"],
            supplier["is_active"],
        ))
        result = cursor.fetchone()
        supplier_id, supplier_name, was_inserted = result
        
        if was_inserted:
            print(f"Inserted supplier {supplier_id}: {supplier_name}")
            inserted_count += 1
        else:
            print(f"Updated supplier {supplier_id}: {supplier_name}")
            updated_count += 1
    
    conn.commit()
    cursor.close()
    conn.close()
    
    return inserted_count, updated_count


if __name__ == "__main__":
    print("Generating supplier records...")
    suppliers = generate_supplier_records()
    print(f"Generated {len(suppliers)} supplier records")
    
    print("\nLoading to database...")
    inserted, updated = insert_suppliers(suppliers)
    
    print(f"\nSuccess. {inserted} inserted, {updated} updated.")