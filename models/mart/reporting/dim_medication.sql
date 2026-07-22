select
    concat(
        coalesce(medication_code_system, 'unknown'),
        '|',
        coalesce(medication_code, 'unknown'),
        '|',
        coalesce(medication_name, 'unknown')
    ) as medication_key,
    medication_code,
    medication_code_system,
    medication_code_display,
    medication_name,
    medication_text,
    count(distinct medication_request_id) as medication_request_count,
    count(distinct patient_id) as patient_count,
    min(authored_date) as first_authored_date,
    max(authored_date) as latest_authored_date
from {{ ref('fct_medicationrequest') }}
group by
    medication_code,
    medication_code_system,
    medication_code_display,
    medication_name,
    medication_text
