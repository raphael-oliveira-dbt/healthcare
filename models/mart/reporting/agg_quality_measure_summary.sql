with reporting_as_of as (

    select max(activity_date) as reporting_as_of_date
    from (
        select max(latest_encounter_date) as activity_date
        from {{ ref('agg_patient_clinical_profile') }}

        union all

        select max(effective_date) as activity_date
        from {{ ref('fct_observation') }}

        union all

        select max(latest_immunization_date) as activity_date
        from {{ ref('agg_patient_clinical_profile') }}
    ) as activity_dates

),

patient_flags as (

    select
        patient_profile.patient_id,
        patient_profile.gender,
        patient_profile.age_years,
        patient_profile.age_band,
        patient_profile.has_diabetes,
        case
            when patient_profile.latest_encounter_date is not null
                and date_diff(reporting_as_of.reporting_as_of_date, patient_profile.latest_encounter_date, month) <= 12
                then 1
            else 0
        end as has_recent_encounter,
        case
            when patient_profile.latest_immunization_date is not null
                and date_diff(reporting_as_of.reporting_as_of_date, patient_profile.latest_immunization_date, month) <= 12
                then 1
            else 0
        end as has_recent_immunization
    from {{ ref('agg_patient_clinical_profile') }} as patient_profile
    cross join reporting_as_of

),

observation_flags as (

    select
        observation.patient_id,
        max(case
            when (
                lower(observation.observation_name) like '%blood pressure%'
                or observation.observation_code in ('85354-9', '8480-6', '8462-4')
            )
            and date_diff(reporting_as_of.reporting_as_of_date, observation.effective_date, month) <= 12
                then 1
            else 0
        end) as has_recent_blood_pressure,
        max(case
            when (
                lower(observation.observation_name) like '%a1c%'
                or lower(observation.observation_name) like '%hemoglobin a1c%'
                or observation.observation_code in ('4548-4', '17856-6')
            )
            and date_diff(reporting_as_of.reporting_as_of_date, observation.effective_date, month) <= 6
                then 1
            else 0
        end) as has_recent_diabetes_monitoring
    from {{ ref('fct_observation') }} as observation
    cross join reporting_as_of
    group by observation.patient_id

),

measure_inputs as (

    select
        patient_flags.patient_id,
        patient_flags.gender,
        patient_flags.age_years,
        patient_flags.age_band,
        patient_flags.has_recent_encounter,
        patient_flags.has_recent_immunization,
        patient_flags.has_diabetes,
        coalesce(observation_flags.has_recent_blood_pressure, 0) as has_recent_blood_pressure,
        coalesce(observation_flags.has_recent_diabetes_monitoring, 0) as has_recent_diabetes_monitoring
    from patient_flags
    left join observation_flags
        on patient_flags.patient_id = observation_flags.patient_id

),

measure_rows as (

    select
        'recent_encounter' as measure_id,
        'Patients with encounter in last 12 months' as measure_name,
        gender,
        age_band,
        1 as denominator_flag,
        has_recent_encounter as numerator_flag
    from measure_inputs

    union all

    select
        'adult_blood_pressure' as measure_id,
        'Adults with blood pressure observation in last 12 months' as measure_name,
        gender,
        age_band,
        case when age_years >= 18 then 1 else 0 end as denominator_flag,
        case when age_years >= 18 then has_recent_blood_pressure else 0 end as numerator_flag
    from measure_inputs

    union all

    select
        'diabetes_a1c_monitoring' as measure_id,
        'Diabetes cohort with A1c observation in last 6 months' as measure_name,
        gender,
        age_band,
        has_diabetes as denominator_flag,
        case when has_diabetes = 1 then has_recent_diabetes_monitoring else 0 end as numerator_flag
    from measure_inputs

    union all

    select
        'recent_immunization_documentation' as measure_id,
        'Patients with completed immunization in last 12 months' as measure_name,
        gender,
        age_band,
        1 as denominator_flag,
        has_recent_immunization as numerator_flag
    from measure_inputs

)

select
    measure_id,
    measure_name,
    gender,
    age_band,
    concat(measure_id, '|', coalesce(gender, 'unknown'), '|', coalesce(age_band, 'unknown')) as quality_measure_key,
    sum(denominator_flag) as denominator_count,
    sum(numerator_flag) as numerator_count,
    sum(denominator_flag) - sum(numerator_flag) as gap_count,
    round(100.0 * sum(numerator_flag) / nullif(sum(denominator_flag), 0), 2) as performance_rate
from measure_rows
group by
    measure_id,
    measure_name,
    gender,
    age_band
