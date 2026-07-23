select
    concat(
        coalesce(fact_procedure.performed_month, cast('1900-01-01' as date)),
        '|',
        procedure.procedure_key,
        '|',
        coalesce(patient.gender, 'unknown'),
        '|',
        coalesce(patient.age_band, 'unknown')
    ) as procedure_volume_report_key,
    fact_procedure.performed_month,
    procedure.procedure_key,
    procedure.procedure_name,
    procedure.procedure_category_display,
    patient.gender,
    patient.age_band,
    count(distinct fact_procedure.procedure_id) as procedure_count,
    count(distinct fact_procedure.patient_id) as patient_count,
    count(distinct case when fact_procedure.is_completed_procedure then fact_procedure.procedure_id end) as completed_procedure_count
from {{ ref('fct_procedure') }} as fact_procedure
left join {{ ref('dim_patient') }} as patient
    on fact_procedure.patient_id = patient.patient_id
left join {{ ref('dim_procedure') }} as procedure
    on concat(
        coalesce(fact_procedure.procedure_code_system, 'unknown'),
        '|',
        coalesce(fact_procedure.procedure_code, 'unknown'),
        '|',
        coalesce(fact_procedure.procedure_name, 'unknown')
    ) = procedure.procedure_key
group by
    fact_procedure.performed_month,
    procedure.procedure_key,
    procedure.procedure_name,
    procedure.procedure_category_display,
    patient.gender,
    patient.age_band
