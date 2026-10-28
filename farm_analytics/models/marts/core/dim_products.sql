with products as (
    select * from {{ ref('stg_products') }}
),

suppliers as (
    select * from {{ ref('stg_suppliers') }}
)

select
    products.product_id,
    products.product_name,
    products.category,
    products.unit,
    products.standard_price,
    products.source_type,
    products.supplier_id,
    suppliers.supplier_name,
    suppliers.supplier_type,
    suppliers.is_local          as is_local_supplier,
    products.is_active
from products
left join suppliers on products.supplier_id = suppliers.supplier_id
