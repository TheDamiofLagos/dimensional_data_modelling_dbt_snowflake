{{
    config(
        materialized='table'
    )
}}

with order_items_with_subcategory as (
    select
        oi.campaign_id,
        p.subcategory_id,
        count(distinct oi.order_id)              as total_orders,
        count(oi.orderitem_id)                   as total_items,
        sum(oi.discounted_subtotal)              as total_revenue,
        sum(oi.subtotal - oi.discounted_subtotal) as total_discounts_given
    from {{ ref('fct_order_items') }} oi
    left join {{ ref('dim_product') }} p on oi.product_id = p.product_id
    where oi.campaign_id is not null
    group by 1, 2
),

subcategory_lookup as (
    select distinct subcategory_id, subcategory, category
    from {{ ref('dim_product') }}
)

select
    mc.campaign_id,
    mc.campaign_name,
    mc.offer_week,
    b.subcategory_id,
    sl.subcategory,
    sl.category,
    b.discount                                                              as campaign_discount_rate,
    coalesce(oi.total_orders, 0)                                            as total_orders,
    coalesce(oi.total_items, 0)                                             as total_items,
    coalesce(oi.total_revenue, 0)                                           as total_revenue,
    coalesce(oi.total_discounts_given, 0)                                   as total_discounts_given,
    {{ safe_divide('oi.total_revenue', 'oi.total_items') }}                 as avg_revenue_per_item,
    {{ safe_divide('oi.total_discounts_given', 'oi.total_revenue') }}       as discount_to_revenue_ratio
from {{ ref('dim_marketing_campaign') }} mc
inner join {{ ref('bridge_campaign_subcategory') }} b on mc.campaign_id = b.campaign_id
inner join subcategory_lookup sl on b.subcategory_id = sl.subcategory_id
left join order_items_with_subcategory oi
    on b.campaign_id = oi.campaign_id
    and b.subcategory_id = oi.subcategory_id