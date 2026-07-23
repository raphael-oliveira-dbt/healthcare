with clinical_events as (

    select
        encounter_month as activity_month,
        patient_id,
        encounter_id as event_id,
        'encounter' as event_type,
        case when is_finished_encounter then 1 else 0 end as completed_event
    from {{ ref('fct_encounter') }}
    where encounter_month is not null

    union all

    select
        effective_month as activity_month,
        patient_id,
        observation_id as event_id,
        'observation' as event_type,
        case when is_final_result then 1 else 0 end as completed_event
    from {{ ref('fct_observation') }}
    where effective_month is not null

    union all

    select
        occurrence_month as activity_month,
        patient_id,
        immunization_id as event_id,
        'immunization' as event_type,
        case when is_completed_immunization then 1 else 0 end as completed_event
    from {{ ref('fct_immunization') }}
    where occurrence_month is not null

    union all

    select
        authored_month as activity_month,
        patient_id,
        medication_request_id as event_id,
        'medication_request' as event_type,
        case when is_order then 1 else 0 end as completed_event
    from {{ ref('fct_medicationrequest') }}
    where authored_month is not null

    union all

    select
        performed_month as activity_month,
        patient_id,
        procedure_id as event_id,
        'procedure' as event_type,
        case when is_completed_procedure then 1 else 0 end as completed_event
    from {{ ref('fct_procedure') }}
    where performed_month is not null

)

select
    concat(
        coalesce(cast(clinical_events.activity_month as string), 'unknown'),
        '|',
        coalesce(patient.gender, 'unknown'),
        '|',
        coalesce(patient.age_band, 'unknown')
    ) as monthly_activity_key,
    clinical_events.activity_month,
    patient.gender,
    patient.age_band,
    count(distinct clinical_events.patient_id) as active_patient_count,
    count(distinct case when clinical_events.event_type = 'encounter' then clinical_events.event_id end) as encounter_count,
    sum(case when clinical_events.event_type = 'encounter' then clinical_events.completed_event else 0 end) as finished_encounter_count,
    count(distinct case when clinical_events.event_type = 'observation' then clinical_events.event_id end) as observation_count,
    sum(case when clinical_events.event_type = 'observation' then clinical_events.completed_event else 0 end) as final_observation_count,
    count(distinct case when clinical_events.event_type = 'immunization' then clinical_events.event_id end) as immunization_count,
    sum(case when clinical_events.event_type = 'immunization' then clinical_events.completed_event else 0 end) as completed_immunization_count,
    count(distinct case when clinical_events.event_type = 'medication_request' then clinical_events.event_id end) as medication_request_count,
    sum(case when clinical_events.event_type = 'medication_request' then clinical_events.completed_event else 0 end) as medication_order_count,
    count(distinct case when clinical_events.event_type = 'procedure' then clinical_events.event_id end) as procedure_count,
    sum(case when clinical_events.event_type = 'procedure' then clinical_events.completed_event else 0 end) as completed_procedure_count,
    count(distinct clinical_events.event_id) as total_clinical_event_count
from clinical_events
left join {{ ref('dim_patient') }} as patient
    on clinical_events.patient_id = patient.patient_id
group by
    clinical_events.activity_month,
    patient.gender,
    patient.age_band
