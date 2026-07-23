select
    concat(
        coalesce(fact_medication.authored_month, cast('1900-01-01' as date)),
        '|',
        medication.medication_key,
        '|',
        coalesce(fact_medication.medication_request_status, 'unknown'),
        '|',
        coalesce(patient.gender, 'unknown'),
        '|',
        coalesce(patient.age_band, 'unknown')
    ) as medication_orders_report_key,
    fact_medication.authored_month,
    medication.medication_key,
    medication.medication_name,
    fact_medication.medication_request_status,
    fact_medication.medication_request_intent,
    patient.gender,
    patient.age_band,
    count(distinct fact_medication.medication_request_id) as medication_request_count,
    count(distinct fact_medication.patient_id) as patient_count,
    count(distinct case when fact_medication.is_active_medication_request then fact_medication.medication_request_id end) as active_medication_request_count,
    count(distinct case when fact_medication.is_order then fact_medication.medication_request_id end) as medication_order_count
from {{ ref('fct_medicationrequest') }} as fact_medication
left join {{ ref('dim_patient') }} as patient
    on fact_medication.patient_id = patient.patient_id
left join {{ ref('dim_medication') }} as medication
    on concat(
        coalesce(fact_medication.medication_code_system, 'unknown'),
        '|',
        coalesce(fact_medication.medication_code, 'unknown'),
        '|',
        coalesce(fact_medication.medication_name, 'unknown')
    ) = medication.medication_key
group by
    fact_medication.authored_month,
    medication.medication_key,
    medication.medication_name,
    fact_medication.medication_request_status,
    fact_medication.medication_request_intent,
    patient.gender,
    patient.age_band
