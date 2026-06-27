"""
Generate worker records for Farm Operations Analytics.

Creates 8 realistic farm workers covering prep, delivery, and supervisory
roles. Names reflect typical Bay Area Chinese-American farm operations.
"""

from db_connection import get_connection


def generate_worker_records():
    """
    Returns a list of worker dictionaries.
    
    Hand-crafted because workers are a small dimension where realistic
    role distribution matters for downstream labor analytics queries.
    """
    workers = [
        {
            "worker_name": "Jose Hernandez",
            "role": "prep",
            "hire_date": "2024-03-15",
            "is_active": True,
        },
        {
            "worker_name": "Maria Lopez",
            "role": "prep",
            "hire_date": "2024-06-01",
            "is_active": True,
        },
        {
            "worker_name": "Carlos Ramirez",
            "role": "driver",
            "hire_date": "2023-11-20",
            "is_active": True,
        },
        {
            "worker_name": "Linh Nguyen",
            "role": "driver",
            "hire_date": "2024-08-10",
            "is_active": True,
        },
        {
            "worker_name": "Wei Chen",
            "role": "multi_role",
            "hire_date": "2023-05-05",
            "is_active": True,
        },
        {
            "worker_name": "Sofia Garcia",
            "role": "multi_role",
            "hire_date": "2025-01-15",
            "is_active": True,
        },
        {
            "worker_name": "David Tran",
            "role": "supervisor",
            "hire_date": "2022-09-01",
            "is_active": True,
        },
        {
            "worker_name": "Pedro Sanchez",
            "role": "prep",
            "hire_date": "2024-02-10",
            "is_active": False,  # Inactive — demonstrates soft delete pattern
        },
    ]
    return workers


def insert_workers(workers):
    """
    Insert worker records into the database.
    
    Idempotent: uses ON CONFLICT to update existing workers rather than
    fail or create duplicates. Safe to re-run after data changes.
    
    Returns:
        tuple: (inserted_count, updated_count)
    """
    conn = get_connection()
    cursor = conn.cursor()
    
    insert_sql = """
        INSERT INTO workers (
            worker_name, role, hire_date, is_active
        ) VALUES (%s, %s, %s, %s)
        ON CONFLICT (worker_name) DO UPDATE SET
            role = EXCLUDED.role,
            hire_date = EXCLUDED.hire_date,
            is_active = EXCLUDED.is_active,
            updated_at = CURRENT_TIMESTAMP
        RETURNING worker_id, worker_name, (xmax = 0) AS was_inserted;
    """
    
    inserted_count = 0
    updated_count = 0
    
    for worker in workers:
        cursor.execute(insert_sql, (
            worker["worker_name"],
            worker["role"],
            worker["hire_date"],
            worker["is_active"],
        ))
        result = cursor.fetchone()
        worker_id, worker_name, was_inserted = result
        
        if was_inserted:
            print(f"Inserted worker {worker_id}: {worker_name}")
            inserted_count += 1
        else:
            print(f"Updated worker {worker_id}: {worker_name}")
            updated_count += 1
    
    conn.commit()
    cursor.close()
    conn.close()
    
    return inserted_count, updated_count


if __name__ == "__main__":
    print("Generating worker records...")
    workers = generate_worker_records()
    print(f"Generated {len(workers)} worker records")
    
    print("\nLoading to database...")
    inserted, updated = insert_workers(workers)
    
    print(f"\nSuccess. {inserted} inserted, {updated} updated.")