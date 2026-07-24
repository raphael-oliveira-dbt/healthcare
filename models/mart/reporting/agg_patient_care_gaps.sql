with reporting_as_of as (

    select max(activity_date) as reporting_as_of_date
    from (
        select max(encounter_date) as activity_date
        from {{ ref('fct_encounter') }}

        union all

        select max(effective_date) as activity_date
        from {{ ref('fct_observation') }}

        union all

        select max(occurrence_date) as activity_date
        from {{ ref('fct_immunization') }}
        where is_completed_immunization
    ) as activity_dates

),

patient as (

    select *
    from {{ ref('dim_patient') }}

),

encounter_activity as (

    select
        patient_id,
        max(encounter_date) as latest_encounter_date
    from {{ ref('fct_encounter') }}
    group by patient_id

),

observation_activity as (

    select
        patient_id,
        max(case
            when lower(observation_name) like '%blood pressure%'
                or observation_code in ('85354-9', '8480-6', '8462-4')
                then effective_date
        end) as latest_blood_pressure_date,
        max(case
            when lower(observation_name) like '%a1c%'
                or lower(observation_name) like '%hemoglobin a1c%'
                or observation_code in ('4548-4', '17856-6')
                then effective_date
        end) as latest_diabetes_monitoring_date
    from {{ ref('fct_observation') }}
    group by patient_id

),

condition_activity as (

    select
        patient_id,
        max(case
            when lower(condition_name) like '%diabetes%' then 1
            else 0
        end) as has_diabetes
    from {{ ref('fct_condition') }}
    group by patient_id

),

immunization_activity as (

    select
        patient_id,
        max(occurrence_date) as latest_immunization_date
    from {{ ref('fct_immunization') }}
    where is_completed_immunization
    group by patient_id

),

medication_activity as (

    select
        patient_id,
        max(case when is_active_medication_request then 1 else 0 end) as has_active_medication_request
    from {{ ref('fct_medicationrequest') }}
    group by patient_id

),

patient_gap_inputs as (

    select
        patient.patient_id,
        patient.gender,
        patient.age_years,
        patient.age_band,
        encounter_activity.latest_encounter_date,
        observation_activity.latest_blood_pressure_date,
        observation_activity.latest_diabetes_monitoring_date,
        immunization_activity.latest_immunization_date,
        reporting_as_of.reporting_as_of_date,
        coalesce(condition_activity.has_diabetes, 0) as has_diabetes,
        coalesce(medication_activity.has_active_medication_request, 0) as has_active_medication_request
    from patient
    cross join reporting_as_of
    left join encounter_activity
        on patient.patient_id = encounter_activity.patient_id
    left join observation_activity
        on patient.patient_id = observation_activity.patient_id
    left join condition_activity
        on patient.patient_id = condition_activity.patient_id
    left join immunization_activity
        on patient.patient_id = immunization_activity.patient_id
    left join medication_activity
        on patient.patient_id = medication_activity.patient_id

),

care_gaps as (

    select
        patient_id,
        gender,
        age_years,
        age_band,
        'annual_wellness_visit' as care_gap_code,
        'No encounter documented in the last 12 months' as care_gap_name,
        latest_encounter_date as latest_relevant_event_date
    from patient_gap_inputs
    where latest_encounter_date is null
        or date_diff(reporting_as_of_date, latest_encounter_date, month) > 12

    union all

    select
        patient_id,
        gender,
        age_years,
        age_band,
        'blood_pressure_observation' as care_gap_code,
        'Adult patient without blood pressure observation in the last 12 months' as care_gap_name,
        latest_blood_pressure_date as latest_relevant_event_date
    from patient_gap_inputs
    where age_years >= 18
        and (
            latest_blood_pressure_date is null
            or date_diff(reporting_as_of_date, latest_blood_pressure_date, month) > 12
        )

    union all

    select
        patient_id,
        gender,
        age_years,
        age_band,
        'diabetes_monitoring' as care_gap_code,
        'Diabetes cohort without A1c observation in the last 6 months' as care_gap_name,
        latest_diabetes_monitoring_date as latest_relevant_event_date
    from patient_gap_inputs
    where has_diabetes = 1
        and (
            latest_diabetes_monitoring_date is null
            or date_diff(reporting_as_of_date, latest_diabetes_monitoring_date, month) > 6
        )

    union all

    select
        patient_id,
        gender,
        age_years,
        age_band,
        'immunization_review' as care_gap_code,
        'No completed immunization documented in the last 12 months' as care_gap_name,
        latest_immunization_date as latest_relevant_event_date
    from patient_gap_inputs
    where latest_immunization_date is null
        or date_diff(reporting_as_of_date, latest_immunization_date, month) > 12

    union all

    select
        patient_id,
        gender,
        age_years,
        age_band,
        'medication_follow_up' as care_gap_code,
        'Active medication request without encounter in the last 12 months' as care_gap_name,
        latest_encounter_date as latest_relevant_event_date
    from patient_gap_inputs
    where has_active_medication_request = 1
        and (
            latest_encounter_date is null
            or date_diff(reporting_as_of_date, latest_encounter_date, month) > 12
        )

)

select
    patient_id,
    gender,
    age_years,
    age_band,
    care_gap_code,
    care_gap_name,
    latest_relevant_event_date,
    'open' as care_gap_status,
    concat(patient_id, '|', care_gap_code) as care_gap_key
from care_gaps
