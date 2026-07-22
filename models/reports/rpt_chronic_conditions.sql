select
    concat(
        condition.condition_key,
        '|',
        coalesce(patient.gender, 'unknown'),
        '|',
        coalesce(patient.age_band, 'unknown')
    ) as chronic_condition_report_key,
    condition.condition_key,
    condition.condition_name,
    condition.condition_code,
    condition.condition_code_system,
    patient.gender,
    patient.age_band,
    count(distinct fact_condition.patient_id) as patient_count,
    count(distinct fact_condition.condition_id) as condition_record_count,
    count(distinct case when fact_condition.is_active_condition then fact_condition.condition_id end) as active_condition_count,
    count(distinct case when fact_condition.is_confirmed_condition then fact_condition.condition_id end) as confirmed_condition_count,
    min(fact_condition.recorded_date) as first_recorded_date,
    max(fact_condition.recorded_date) as latest_recorded_date
from {{ ref('fct_condition') }} as fact_condition
left join {{ ref('dim_patient') }} as patient
    on fact_condition.patient_id = patient.patient_id
left join {{ ref('dim_condition') }} as condition
    on concat(
        coalesce(fact_condition.condition_code_system, 'unknown'),
        '|',
        coalesce(fact_condition.condition_code, 'unknown'),
        '|',
        coalesce(fact_condition.condition_name, 'unknown')
    ) = condition.condition_key
group by
    condition.condition_key,
    condition.condition_name,
    condition.condition_code,
    condition.condition_code_system,
    patient.gender,
    patient.age_band
