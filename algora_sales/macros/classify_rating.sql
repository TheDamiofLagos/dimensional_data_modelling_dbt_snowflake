{% macro classify_rating(rating_col) %}
    CASE
        WHEN {{ rating_col }} >= 4  THEN 'high'
        WHEN {{ rating_col }} >= 3  THEN 'medium'
        ELSE                             'low'
    END
{% endmacro %}
