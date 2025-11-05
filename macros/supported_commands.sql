{% macro is_supported_command() %}
    {%- set supported_commands = ["run", "test",  "build", "snapshot"] -%}
    {%- set actual_command = flags.WHICH -%}
    {{ return(actual_command in supported_commands) }}
{% endmacro %}