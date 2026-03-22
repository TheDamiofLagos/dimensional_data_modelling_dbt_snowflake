{{
    config(
        materialized='table'
    )
}}

with campaign_orders as (
    select
        campaign_id,
        count(distinct order_id)                                               as total_orders,
        count(orderitem_id)                                                    as total_items,
        sum(discounted_subtotal)                                               as total_revenue,
        sum(subtotal - discounted_subtotal)                                    as total_discounts_given,
        sum(case when is_campaign_order then discounted_subtotal else 0 end)   as campaign_driven_revenue
    from {{ ref('fct_order_items') }}
    where campaign_id is not null
    group by campaign_id
)

select
    mc.campaign_id,
    mc.campaign_name,
    mc.offer_week,
    coalesce(co.total_orders, 0)                                         as total_orders,
    coalesce(co.total_items, 0)                                          as total_items,
    coalesce(co.total_revenue, 0)                                        as total_revenue,
    coalesce(co.total_discounts_given, 0)                                as total_discounts_given,
    coalesce(co.campaign_driven_revenue, 0)                              as campaign_driven_revenue,
    {{ safe_divide('co.campaign_driven_revenue', 'co.total_revenue') }}  as campaign_revenue_rate
from {{ ref('dim_marketing_campaign') }} mc
left join campaign_orders co on mc.campaign_id = co.campaign_id
