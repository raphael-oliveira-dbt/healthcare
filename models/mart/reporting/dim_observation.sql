select
    concat(
        coalesce(observation_code_system, 'unknown'),
        '|',
        coalesce(observation_code, 'unknown'),
        '|',
        coalesce(observation_name, 'unknown')
    ) as observation_key,
    observation_code,
    observation_code_system,
    observation_code_display,
    observation_name,
    observation_text,
    observation_category_code,
    observation_category_display,
    count(distinct observation_id) as observation_count,
    count(distinct patient_id) as patient_count,
    min(effective_date) as first_effective_date,
    max(effective_date) as latest_effective_date
from {{ ref('fct_observation') }}
group by
    observation_code,
    observation_code_system,
    observation_code_display,
    observation_name,
    observation_text,
    observation_category_code,
    observation_category_display
