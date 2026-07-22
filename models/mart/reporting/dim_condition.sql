select
    concat(
        coalesce(condition_code_system, 'unknown'),
        '|',
        coalesce(condition_code, 'unknown'),
        '|',
        coalesce(condition_name, 'unknown')
    ) as condition_key,
    condition_code,
    condition_code_system,
    condition_code_display,
    condition_name,
    condition_text,
    count(distinct condition_id) as condition_record_count,
    count(distinct patient_id) as patient_count,
    min(recorded_date) as first_recorded_date,
    max(recorded_date) as latest_recorded_date
from {{ ref('fct_condition') }}
group by
    condition_code,
    condition_code_system,
    condition_code_display,
    condition_name,
    condition_text
