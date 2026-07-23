select
    fact_observation.effective_month,
    observation.observation_key,
    observation.observation_name,
    observation.observation_category_display,
    fact_observation.value_unit,
    patient.gender,
    patient.age_band,
    concat(
        coalesce(fact_observation.effective_month, cast('1900-01-01' as date)),
        '|',
        observation.observation_key,
        '|',
        coalesce(patient.gender, 'unknown'),
        '|',
        coalesce(patient.age_band, 'unknown')
    ) as observation_trends_report_key,
    count(distinct fact_observation.observation_id) as observation_count,
    count(distinct fact_observation.patient_id) as patient_count,
    avg(fact_observation.value_quantity) as average_value_quantity,
    min(fact_observation.value_quantity) as minimum_value_quantity,
    max(fact_observation.value_quantity) as maximum_value_quantity,
    count(distinct case
        when fact_observation.interpretation_code is not null
            and lower(coalesce(fact_observation.interpretation_code, '')) not in ('n', 'normal')
            then fact_observation.observation_id
    end) as abnormal_observation_count
from {{ ref('fct_observation') }} as fact_observation
left join {{ ref('dim_patient') }} as patient
    on fact_observation.patient_id = patient.patient_id
left join {{ ref('dim_observation') }} as observation
    on concat(
        coalesce(fact_observation.observation_code_system, 'unknown'),
        '|',
        coalesce(fact_observation.observation_code, 'unknown'),
        '|',
        coalesce(fact_observation.observation_category_code, 'unknown'),
        '|',
        coalesce(fact_observation.observation_category_display, 'unknown'),
        '|',
        coalesce(fact_observation.observation_name, 'unknown')
    ) = observation.observation_key
where fact_observation.has_numeric_result
group by
    fact_observation.effective_month,
    observation.observation_key,
    observation.observation_name,
    observation.observation_category_display,
    fact_observation.value_unit,
    patient.gender,
    patient.age_band
