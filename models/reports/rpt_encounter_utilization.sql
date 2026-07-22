select
    monthly_activity_key as encounter_utilization_report_key,
    activity_month,
    gender,
    age_band,
    active_patient_count,
    encounter_count,
    finished_encounter_count,
    round(100.0 * finished_encounter_count / nullif(encounter_count, 0), 2) as finished_encounter_rate,
    total_clinical_event_count
from {{ ref('agg_monthly_clinical_activity') }}
where encounter_count > 0
