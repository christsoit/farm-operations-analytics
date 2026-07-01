"""
Generate product records for Farm Operations Analytics.

Creates ~35 Chinese-American vegetables and related produce items
typical of a Bay Area Asian produce distribution business.

Products are linked to suppliers created in generate_suppliers.py.
Looks up supplier IDs by name before inserting products.

Idempotent: safe to re-run. Uses ON CONFLICT to update existing products.
"""

from db_connection import get_connection


# =========================================
# PRODUCT CATALOG
# Hand-crafted for realistic Bay Area Asian produce distribution
# =========================================

PRODUCTS = [
    # ─── LEAFY GREENS ─────────────────────────────────────
    # Most common Chinese vegetables — high volume movers
    {
        "product_name": "Bok Choy",
        "category": "leafy_green",
        "unit": "lb",
        "standard_price": 2.50,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Baby Bok Choy",
        "category": "leafy_green",
        "unit": "lb",
        "standard_price": 3.00,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Gai Lan (Chinese Broccoli)",
        "category": "leafy_green",
        "unit": "lb",
        "standard_price": 3.25,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Choy Sum",
        "category": "leafy_green",
        "unit": "lb",
        "standard_price": 2.75,
        "source_type": "outsourced",
        "supplier_name": "Salinas Valley Greens",
        "is_active": True,
    },
    {
        "product_name": "Napa Cabbage",
        "category": "leafy_green",
        "unit": "lb",
        "standard_price": 1.50,
        "source_type": "outsourced",
        "supplier_name": "Salinas Valley Greens",
        "is_active": True,
    },
    {
        "product_name": "Water Spinach (Ong Choy)",
        "category": "leafy_green",
        "unit": "lb",
        "standard_price": 3.50,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Yu Choy",
        "category": "leafy_green",
        "unit": "lb",
        "standard_price": 3.00,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Chinese Mustard Greens",
        "category": "leafy_green",
        "unit": "lb",
        "standard_price": 2.75,
        "source_type": "outsourced",
        "supplier_name": "Watsonville Organic Co-op",
        "is_active": True,
    },
    
    # ─── ROOT VEGETABLES ──────────────────────────────────
    {
        "product_name": "Daikon",
        "category": "root",
        "unit": "lb",
        "standard_price": 1.25,
        "source_type": "outsourced",
        "supplier_name": "Central Valley Produce",
        "is_active": True,
    },
    {
        "product_name": "Lotus Root",
        "category": "root",
        "unit": "lb",
        "standard_price": 4.50,
        "source_type": "outsourced",
        "supplier_name": "Bay Area Wholesale Market",
        "is_active": True,
    },
    {
        "product_name": "Burdock Root (Gobo)",
        "category": "root",
        "unit": "lb",
        "standard_price": 3.75,
        "source_type": "outsourced",
        "supplier_name": "Oakland Asian Produce",
        "is_active": True,
    },
    {
        "product_name": "Taro",
        "category": "root",
        "unit": "lb",
        "standard_price": 2.50,
        "source_type": "outsourced",
        "supplier_name": "Sunshine Imports",
        "is_active": True,
    },
    {
        "product_name": "Chinese Yam",
        "category": "root",
        "unit": "lb",
        "standard_price": 3.50,
        "source_type": "outsourced",
        "supplier_name": "Sunshine Imports",
        "is_active": True,
    },
    
    # ─── MELONS & GOURDS ──────────────────────────────────
    {
        "product_name": "Winter Melon",
        "category": "melon",
        "unit": "lb",
        "standard_price": 1.75,
        "source_type": "outsourced",
        "supplier_name": "Central Valley Produce",
        "is_active": True,
    },
    {
        "product_name": "Bitter Melon",
        "category": "melon",
        "unit": "lb",
        "standard_price": 3.25,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Fuzzy Melon (Mo Qua)",
        "category": "melon",
        "unit": "lb",
        "standard_price": 2.50,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Chinese Long Squash (Sing Qua)",
        "category": "melon",
        "unit": "lb",
        "standard_price": 2.25,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Opo Squash",
        "category": "melon",
        "unit": "lb",
        "standard_price": 1.75,
        "source_type": "outsourced",
        "supplier_name": "Watsonville Organic Co-op",
        "is_active": True,
    },
    
    # ─── PEAS & BEANS ─────────────────────────────────────
    {
        "product_name": "Snow Peas",
        "category": "legume",
        "unit": "lb",
        "standard_price": 4.50,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Pea Shoots",
        "category": "legume",
        "unit": "lb",
        "standard_price": 6.00,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Long Beans (Yard-long)",
        "category": "legume",
        "unit": "lb",
        "standard_price": 3.50,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Edamame",
        "category": "legume",
        "unit": "lb",
        "standard_price": 4.00,
        "source_type": "outsourced",
        "supplier_name": "Sunshine Imports",
        "is_active": True,
    },
    
    # ─── HERBS & AROMATICS ────────────────────────────────
    {
        "product_name": "Chinese Chives",
        "category": "herb",
        "unit": "bunch",
        "standard_price": 2.00,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Cilantro",
        "category": "herb",
        "unit": "bunch",
        "standard_price": 1.50,
        "source_type": "outsourced",
        "supplier_name": "Salinas Valley Greens",
        "is_active": True,
    },
    {
        "product_name": "Thai Basil",
        "category": "herb",
        "unit": "bunch",
        "standard_price": 2.25,
        "source_type": "outsourced",
        "supplier_name": "Salinas Valley Greens",
        "is_active": True,
    },
    {
        "product_name": "Green Onions",
        "category": "herb",
        "unit": "bunch",
        "standard_price": 1.25,
        "source_type": "outsourced",
        "supplier_name": "Central Valley Produce",
        "is_active": True,
    },
    {
        "product_name": "Ginger",
        "category": "herb",
        "unit": "lb",
        "standard_price": 3.50,
        "source_type": "outsourced",
        "supplier_name": "Bay Area Wholesale Market",
        "is_active": True,
    },
    
    # ─── EGGPLANTS & PEPPERS ──────────────────────────────
    {
        "product_name": "Chinese Eggplant",
        "category": "fruit_vegetable",
        "unit": "lb",
        "standard_price": 2.75,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    {
        "product_name": "Thai Eggplant",
        "category": "fruit_vegetable",
        "unit": "lb",
        "standard_price": 3.25,
        "source_type": "own_farm",
        "supplier_name": "Yong Sheng Farm",
        "is_active": True,
    },
    
    # ─── MUSHROOMS ────────────────────────────────────────
    {
        "product_name": "Shiitake Mushrooms",
        "category": "mushroom",
        "unit": "lb",
        "standard_price": 8.50,
        "source_type": "outsourced",
        "supplier_name": "Oakland Asian Produce",
        "is_active": True,
    },
    {
        "product_name": "Enoki Mushrooms",
        "category": "mushroom",
        "unit": "lb",
        "standard_price": 6.00,
        "source_type": "outsourced",
        "supplier_name": "Sunshine Imports",
        "is_active": True,
    },
    {
        "product_name": "King Oyster Mushrooms",
        "category": "mushroom",
        "unit": "lb",
        "standard_price": 7.50,
        "source_type": "outsourced",
        "supplier_name": "Oakland Asian Produce",
        "is_active": True,
    },
    
    # ─── BEAN SPROUTS & TOFU ──────────────────────────────
    {
        "product_name": "Mung Bean Sprouts",
        "category": "sprouts",
        "unit": "lb",
        "standard_price": 2.00,
        "source_type": "outsourced",
        "supplier_name": "Bay Area Wholesale Market",
        "is_active": True,
    },
    {
        "product_name": "Soybean Sprouts",
        "category": "sprouts",
        "unit": "lb",
        "standard_price": 2.25,
        "source_type": "outsourced",
        "supplier_name": "Bay Area Wholesale Market",
        "is_active": True,
    },
    
    # ─── DISCONTINUED PRODUCT ─────────────────────────────
    # Demonstrates soft-delete pattern
    {
        "product_name": "Seasonal Fuji Apples",
        "category": "fruit",
        "unit": "lb",
        "standard_price": 2.50,
        "source_type": "outsourced",
        "supplier_name": "Half Moon Bay Farms",
        "is_active": False,  # Inactive — seasonal item no longer offered
    },
]


# =========================================
# SUPPLIER ID LOOKUP
# =========================================

def get_supplier_id_map():
    """
    Query the database to get a dict mapping supplier_name -> supplier_id.
    
    This is needed because products reference suppliers by ID, but our
    product catalog references them by name (more readable in code).
    
    Returns:
        dict: {supplier_name: supplier_id}
    """
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("SELECT supplier_id, supplier_name FROM suppliers;")
    rows = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    # Build a dict: {name: id}
    return {name: id for id, name in rows}


# =========================================
# DATABASE INSERT
# =========================================

def insert_products(products):
    """
    Insert product records into the database.
    
    Resolves supplier_name to supplier_id by looking up the suppliers table.
    Idempotent via ON CONFLICT.
    
    Returns:
        tuple: (inserted_count, updated_count)
    """
    # Look up supplier IDs first
    supplier_map = get_supplier_id_map()
    print(f"Loaded {len(supplier_map)} suppliers for FK lookup")
    
    conn = get_connection()
    cursor = conn.cursor()
    
    insert_sql = """
        INSERT INTO products (
            product_name, category, unit, standard_price, 
            source_type, supplier_id, is_active
        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (product_name) DO UPDATE SET
            category = EXCLUDED.category,
            unit = EXCLUDED.unit,
            standard_price = EXCLUDED.standard_price,
            source_type = EXCLUDED.source_type,
            supplier_id = EXCLUDED.supplier_id,
            is_active = EXCLUDED.is_active,
            updated_at = CURRENT_TIMESTAMP
        RETURNING product_id, product_name, (xmax = 0) AS was_inserted;
    """
    
    inserted_count = 0
    updated_count = 0
    skipped_count = 0
    
    for product in products:
        # Look up supplier_id from supplier_name
        supplier_name = product["supplier_name"]
        supplier_id = supplier_map.get(supplier_name)
        
        if supplier_id is None:
            print(f"WARNING: Skipping {product['product_name']} - supplier '{supplier_name}' not found")
            skipped_count += 1
            continue
        
        cursor.execute(insert_sql, (
            product["product_name"],
            product["category"],
            product["unit"],
            product["standard_price"],
            product["source_type"],
            supplier_id,
            product["is_active"],
        ))
        result = cursor.fetchone()
        product_id, product_name, was_inserted = result
        
        if was_inserted:
            print(f"Inserted product {product_id}: {product_name} ({product['category']})")
            inserted_count += 1
        else:
            print(f"Updated product {product_id}: {product_name}")
            updated_count += 1
    
    conn.commit()
    cursor.close()
    conn.close()
    
    return inserted_count, updated_count, skipped_count


# =========================================
# MAIN
# =========================================

if __name__ == "__main__":
    print(f"Loading {len(PRODUCTS)} product records...")
    
    # Show category breakdown
    category_counts = {}
    for p in PRODUCTS:
        category_counts[p['category']] = category_counts.get(p['category'], 0) + 1
    print(f"Categories: {category_counts}")
    
    print("\nLoading to database...")
    inserted, updated, skipped = insert_products(PRODUCTS)
    
    print(f"\nSuccess. {inserted} inserted, {updated} updated, {skipped} skipped.")