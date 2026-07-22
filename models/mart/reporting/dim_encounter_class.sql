select
    concat(
        coalesce(encounter_class_code, 'unknown'),
        '|',
        coalesce(encounter_class_display, 'unknown')
    ) as encounter_class_key,
    encounter_class_code,
    encounter_class_display,
    count(distinct encounter_id) as encounter_count,
    count(distinct patient_id) as patient_count,
    min(encounter_date) as first_encounter_date,
    max(encounter_date) as latest_encounter_date
from {{ ref('fct_encounter') }}
group by
    encounter_class_code,
    encounter_class_display
