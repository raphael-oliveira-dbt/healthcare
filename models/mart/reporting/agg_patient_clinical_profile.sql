with encounter_profile as (

    select
        patient_id,
        count(distinct encounter_id) as encounter_count,
        count(distinct case when is_finished_encounter then encounter_id end) as finished_encounter_count,
        max(encounter_date) as latest_encounter_date
    from {{ ref('fct_encounter') }}
    group by patient_id

),

condition_profile as (

    select
        patient_id,
        count(distinct condition_id) as condition_count,
        count(distinct case when is_active_condition then condition_id end) as active_condition_count,
        count(distinct case when is_confirmed_condition then condition_id end) as confirmed_condition_count,
        max(case when lower(condition_name) like '%diabetes%' then 1 else 0 end) as has_diabetes,
        max(case when lower(condition_name) like '%hypertension%' then 1 else 0 end) as has_hypertension,
        max(case when lower(condition_name) like '%asthma%' then 1 else 0 end) as has_asthma,
        max(case when lower(condition_name) like '%depression%' then 1 else 0 end) as has_depression,
        max(recorded_date) as latest_condition_recorded_date
    from {{ ref('fct_condition') }}
    group by patient_id

),

observation_profile as (

    select
        patient_id,
        count(distinct observation_id) as observation_count,
        count(distinct case when has_numeric_result then observation_id end) as numeric_observation_count,
        count(distinct case
            when interpretation_code is not null
                and lower(coalesce(interpretation_code, '')) not in ('n', 'normal')
                then observation_id
        end) as abnormal_observation_count,
        max(effective_date) as latest_observation_date
    from {{ ref('fct_observation') }}
    group by patient_id

),

immunization_profile as (

    select
        patient_id,
        count(distinct immunization_id) as immunization_count,
        count(distinct case when is_completed_immunization then immunization_id end) as completed_immunization_count,
        max(occurrence_date) as latest_immunization_date
    from {{ ref('fct_immunization') }}
    group by patient_id

),

medication_profile as (

    select
        patient_id,
        count(distinct medication_request_id) as medication_request_count,
        count(distinct case when is_order then medication_request_id end) as medication_order_count,
        count(distinct case when is_active_medication_request then medication_request_id end) as active_medication_request_count,
        max(authored_date) as latest_medication_request_date
    from {{ ref('fct_medicationrequest') }}
    group by patient_id

),

procedure_profile as (

    select
        patient_id,
        count(distinct procedure_id) as procedure_count,
        count(distinct case when is_completed_procedure then procedure_id end) as completed_procedure_count,
        max(performed_date) as latest_procedure_date
    from {{ ref('fct_procedure') }}
    group by patient_id

)

select
    patient.patient_id,
    patient.patient_name,
    patient.gender,
    patient.birth_date,
    patient.age_years,
    patient.age_band,
    patient.is_deceased,
    coalesce(encounter_profile.encounter_count, 0) as encounter_count,
    coalesce(encounter_profile.finished_encounter_count, 0) as finished_encounter_count,
    encounter_profile.latest_encounter_date,
    coalesce(condition_profile.condition_count, 0) as condition_count,
    coalesce(condition_profile.active_condition_count, 0) as active_condition_count,
    coalesce(condition_profile.confirmed_condition_count, 0) as confirmed_condition_count,
    coalesce(condition_profile.has_diabetes, 0) as has_diabetes,
    coalesce(condition_profile.has_hypertension, 0) as has_hypertension,
    coalesce(condition_profile.has_asthma, 0) as has_asthma,
    coalesce(condition_profile.has_depression, 0) as has_depression,
    condition_profile.latest_condition_recorded_date,
    coalesce(observation_profile.observation_count, 0) as observation_count,
    coalesce(observation_profile.numeric_observation_count, 0) as numeric_observation_count,
    coalesce(observation_profile.abnormal_observation_count, 0) as abnormal_observation_count,
    observation_profile.latest_observation_date,
    coalesce(immunization_profile.immunization_count, 0) as immunization_count,
    coalesce(immunization_profile.completed_immunization_count, 0) as completed_immunization_count,
    immunization_profile.latest_immunization_date,
    coalesce(medication_profile.medication_request_count, 0) as medication_request_count,
    coalesce(medication_profile.medication_order_count, 0) as medication_order_count,
    coalesce(medication_profile.active_medication_request_count, 0) as active_medication_request_count,
    medication_profile.latest_medication_request_date,
    coalesce(procedure_profile.procedure_count, 0) as procedure_count,
    coalesce(procedure_profile.completed_procedure_count, 0) as completed_procedure_count,
    procedure_profile.latest_procedure_date
from {{ ref('dim_patient') }} as patient
left join encounter_profile
    on patient.patient_id = encounter_profile.patient_id
left join condition_profile
    on patient.patient_id = condition_profile.patient_id
left join observation_profile
    on patient.patient_id = observation_profile.patient_id
left join immunization_profile
    on patient.patient_id = immunization_profile.patient_id
left join medication_profile
    on patient.patient_id = medication_profile.patient_id
left join procedure_profile
    on patient.patient_id = procedure_profile.patient_id
