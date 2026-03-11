with supplier as (
    select * from {{ ref('base_supplier') }}
)

select
    supplier_id,
    supplier_name,
    email
from supplier
