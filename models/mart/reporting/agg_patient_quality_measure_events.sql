with measure_definitions as (

    select
        measure_id,
        lower(observation_name_pattern) as observation_name_pattern
    from {{ ref('hedis_measure_definitions') }}

),

value_sets as (

    select
        measure_id,
        code
    from {{ ref('hedis_measure_value_sets') }}

),

observation as (

    select
        patient_id,
        observation_code,
        lower(observation_name) as observation_name,
        effective_date
    from {{ ref('fct_observation') }}

),

name_matched_events as (

    select
        observation.patient_id,
        measure_definitions.measure_id,
        observation.effective_date
    from observation
    inner join measure_definitions
        on measure_definitions.observation_name_pattern is not null
        and observation.observation_name like measure_definitions.observation_name_pattern

),

code_matched_events as (

    select
        observation.patient_id,
        value_sets.measure_id,
        observation.effective_date
    from observation
    inner join value_sets
        on observation.observation_code = value_sets.code

),

qualifying_events as (

    select * from name_matched_events
    union all
    select * from code_matched_events

)

select
    concat(patient_id, '|', measure_id) as patient_measure_key,
    patient_id,
    measure_id,
    max(effective_date) as latest_qualifying_event_date
from qualifying_events
group by
    patient_id,
    measure_id
