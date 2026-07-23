with care_gap_counts as (

    select
        patient_id,
        count(*) as open_care_gap_count
    from {{ ref('agg_patient_care_gaps') }}
    group by patient_id

)

select
    profile.patient_id as high_risk_cohort_report_key,
    profile.patient_id,
    profile.patient_name,
    profile.gender,
    profile.age_years,
    profile.age_band,
    profile.encounter_count,
    profile.active_condition_count,
    profile.abnormal_observation_count,
    profile.active_medication_request_count,
    coalesce(care_gap_counts.open_care_gap_count, 0) as open_care_gap_count,
    case
        when profile.abnormal_observation_count > 0
            or coalesce(care_gap_counts.open_care_gap_count, 0) >= 2
            or profile.active_condition_count >= 3
            then 'high'
        when profile.active_condition_count > 0
            or profile.active_medication_request_count > 0
            or coalesce(care_gap_counts.open_care_gap_count, 0) = 1
            then 'moderate'
        else 'low'
    end as risk_tier
from {{ ref('agg_patient_clinical_profile') }} as profile
left join care_gap_counts
    on profile.patient_id = care_gap_counts.patient_id
