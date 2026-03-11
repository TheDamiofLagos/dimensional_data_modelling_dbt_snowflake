with customer as (
    select * from {{ ref('base_customer') }}
)

select
    customer_id,
    first_name,
    last_name,
    {{ full_name('first_name', 'last_name') }}  as full_name,
    email,
    country
from customer
