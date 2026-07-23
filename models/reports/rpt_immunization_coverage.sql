select
    concat(
        coalesce(fact_immunization.occurrence_month, cast('1900-01-01' as date)),
        '|',
        coalesce(fact_immunization.vaccine_code, 'unknown'),
        '|',
        coalesce(patient.gender, 'unknown'),
        '|',
        coalesce(patient.age_band, 'unknown')
    ) as immunization_coverage_report_key,
    fact_immunization.occurrence_month,
    fact_immunization.vaccine_code,
    fact_immunization.vaccine_name,
    patient.gender,
    patient.age_band,
    count(distinct fact_immunization.patient_id) as patient_count,
    count(distinct fact_immunization.immunization_id) as immunization_count,
    count(distinct case when fact_immunization.is_completed_immunization then fact_immunization.immunization_id end) as completed_immunization_count,
    round(
        100.0 * count(distinct case when fact_immunization.is_completed_immunization then fact_immunization.immunization_id end)
            / nullif(count(distinct fact_immunization.immunization_id), 0),
        2
    ) as completed_immunization_rate
from {{ ref('fct_immunization') }} as fact_immunization
left join {{ ref('dim_patient') }} as patient
    on fact_immunization.patient_id = patient.patient_id
group by
    fact_immunization.occurrence_month,
    fact_immunization.vaccine_code,
    fact_immunization.vaccine_name,
    patient.gender,
    patient.age_band
