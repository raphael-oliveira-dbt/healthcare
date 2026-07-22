with safety_signal_events as (

    select
        patient_id,
        observation_id as source_event_id,
        'abnormal_observation' as safety_signal_type,
        observation_name as safety_signal_name,
        effective_date as signal_date
    from {{ ref('fct_observation') }}
    where interpretation_code is not null
        and lower(coalesce(interpretation_code, '')) not in ('n', 'normal')

    union all

    select
        patient_id,
        medication_request_id as source_event_id,
        'active_medication_request' as safety_signal_type,
        medication_name as safety_signal_name,
        authored_date as signal_date
    from {{ ref('fct_medicationrequest') }}
    where is_active_medication_request

    union all

    select
        patient_id,
        condition_id as source_event_id,
        'active_condition' as safety_signal_type,
        condition_name as safety_signal_name,
        recorded_date as signal_date
    from {{ ref('fct_condition') }}
    where is_active_condition

)

select
    concat(
        coalesce(safety_signal_type, 'unknown'),
        '|',
        coalesce(safety_signal_name, 'unknown'),
        '|',
        coalesce(patient.gender, 'unknown'),
        '|',
        coalesce(patient.age_band, 'unknown')
    ) as safety_signals_report_key,
    safety_signal_type,
    safety_signal_name,
    patient.gender,
    patient.age_band,
    count(distinct safety_signal_events.patient_id) as patient_count,
    count(distinct safety_signal_events.source_event_id) as signal_event_count,
    min(safety_signal_events.signal_date) as first_signal_date,
    max(safety_signal_events.signal_date) as latest_signal_date
from safety_signal_events
left join {{ ref('dim_patient') }} as patient
    on safety_signal_events.patient_id = patient.patient_id
group by
    safety_signal_type,
    safety_signal_name,
    patient.gender,
    patient.age_band
