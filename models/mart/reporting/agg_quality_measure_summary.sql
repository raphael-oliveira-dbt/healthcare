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

measure_rules as (

    -- Measure parameters are governed in seeds/hedis_measure_definitions.csv
    select
        max(case when measure_id = 'adult_blood_pressure' then measure_label end) as bp_measure_label,
        max(case when measure_id = 'adult_blood_pressure' then lookback_months end) as bp_lookback_months,
        max(case when measure_id = 'adult_blood_pressure' then min_age_years end) as bp_min_age_years,
        max(case when measure_id = 'adult_blood_pressure' then max_age_years end) as bp_max_age_years,
        max(case when measure_id = 'diabetes_a1c_monitoring' then measure_label end) as a1c_measure_label,
        max(case when measure_id = 'diabetes_a1c_monitoring' then lookback_months end) as a1c_lookback_months,
        max(case when measure_id = 'diabetes_a1c_monitoring' then min_age_years end) as a1c_min_age_years,
        max(case when measure_id = 'diabetes_a1c_monitoring' then max_age_years end) as a1c_max_age_years
    from {{ ref('hedis_measure_definitions') }}

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
        measure_events.patient_id,
        max(case
            when measure_events.measure_id = 'adult_blood_pressure'
                and date_diff(reporting_as_of.reporting_as_of_date, measure_events.latest_qualifying_event_date, month)
                    <= measure_rules.bp_lookback_months
                then 1
            else 0
        end) as has_recent_blood_pressure,
        max(case
            when measure_events.measure_id = 'diabetes_a1c_monitoring'
                and date_diff(reporting_as_of.reporting_as_of_date, measure_events.latest_qualifying_event_date, month)
                    <= measure_rules.a1c_lookback_months
                then 1
            else 0
        end) as has_recent_diabetes_monitoring
    from {{ ref('agg_patient_quality_measure_events') }} as measure_events
    cross join reporting_as_of
    cross join measure_rules
    group by measure_events.patient_id

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
        coalesce(observation_flags.has_recent_diabetes_monitoring, 0) as has_recent_diabetes_monitoring,
        case
            when (measure_rules.bp_min_age_years is null or patient_flags.age_years >= measure_rules.bp_min_age_years)
                and (measure_rules.bp_max_age_years is null or patient_flags.age_years <= measure_rules.bp_max_age_years)
                then 1
            else 0
        end as is_bp_age_eligible,
        case
            when (measure_rules.a1c_min_age_years is null or patient_flags.age_years >= measure_rules.a1c_min_age_years)
                and (measure_rules.a1c_max_age_years is null or patient_flags.age_years <= measure_rules.a1c_max_age_years)
                then 1
            else 0
        end as is_a1c_age_eligible,
        concat(
            'Adults with ', measure_rules.bp_measure_label,
            ' in last ', cast(measure_rules.bp_lookback_months as string), ' months'
        ) as bp_measure_name,
        concat(
            'Diabetes cohort with ', measure_rules.a1c_measure_label,
            ' in last ', cast(measure_rules.a1c_lookback_months as string), ' months'
        ) as a1c_measure_name
    from patient_flags
    cross join measure_rules
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
        bp_measure_name as measure_name,
        gender,
        age_band,
        is_bp_age_eligible as denominator_flag,
        case when is_bp_age_eligible = 1 then has_recent_blood_pressure else 0 end as numerator_flag
    from measure_inputs

    union all

    select
        'diabetes_a1c_monitoring' as measure_id,
        a1c_measure_name as measure_name,
        gender,
        age_band,
        case when has_diabetes = 1 and is_a1c_age_eligible = 1 then 1 else 0 end as denominator_flag,
        case
            when has_diabetes = 1 and is_a1c_age_eligible = 1 then has_recent_diabetes_monitoring
            else 0
        end as numerator_flag
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
