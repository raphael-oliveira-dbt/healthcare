select
    concat(
        care_gap_code,
        '|',
        coalesce(gender, 'unknown'),
        '|',
        coalesce(age_band, 'unknown')
    ) as preventive_care_gaps_report_key,
    care_gap_code,
    care_gap_name,
    gender,
    age_band,
    care_gap_status,
    count(distinct patient_id) as patient_count,
    min(latest_relevant_event_date) as oldest_latest_relevant_event_date,
    max(latest_relevant_event_date) as newest_latest_relevant_event_date
from {{ ref('agg_patient_care_gaps') }}
group by
    care_gap_code,
    care_gap_name,
    gender,
    age_band,
    care_gap_status
