{% macro apply_discount(price, discount_rate) %}
    ({{ price }} * (1 - {{ discount_rate }}))::numeric(16, 2)
{% endmacro %}
