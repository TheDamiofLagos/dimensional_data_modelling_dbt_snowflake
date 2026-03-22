{{ 
    config(
        materialized='table'
        ) 
}}

select
    p.product_id,
    p.name as product_name,
    p.price as product_price,
    p.description as product_description,
    s.subcategory_id,
    s.subcategory_name as subcategory,
    c.category_name as category,
    current_date() as dbt_run_at
from {{ ref('prep_product')}} as p 
left join {{ ref('prep_subcategory')}} as s 
on p.subcategory_id = s.subcategory_id
left join {{ ref('prep_category')}} as c 
on s.category_id = c.category_id

