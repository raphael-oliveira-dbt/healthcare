select
    concat(
        coalesce(gender, 'unknown'),
        '|',
        coalesce(age_band, 'unknown'),
        '|',
        case when is_deceased then 'deceased' else 'living' end
    ) as population_overview_report_key,
    gender,
    age_band,
    is_deceased,
    count(distinct patient_id) as patient_count,
    avg(age_years) as average_age_years,
    sum(encounter_count) as encounter_count,
    sum(condition_count) as condition_count,
    sum(active_condition_count) as active_condition_count,
    sum(observation_count) as observation_count,
    sum(completed_immunization_count) as completed_immunization_count,
    sum(medication_request_count) as medication_request_count,
    sum(procedure_count) as procedure_count
from {{ ref('agg_patient_clinical_profile') }}
group by
    gender,
    age_band,
    is_deceased
