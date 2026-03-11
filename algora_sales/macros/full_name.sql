{% macro full_name(first_name, last_name) %}
    CONCAT_WS(' ', {{ last_name }}, {{ first_name }})
{% endmacro %}
