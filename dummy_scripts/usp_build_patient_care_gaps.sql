/* =====================================================================================
   Procedure:    dbo.usp_build_patient_care_gaps
   Purpose:      Rebuilds rpt.patient_care_gaps (one row per patient per open care gap)
   Called by:    dbo.usp_nightly_quality_refresh  <-  Control-M job QUAL_NIGHTLY_04
   Depends on:   edw.fct_encounter, edw.fct_observation, edw.fct_condition,
                 edw.fct_immunization, edw.fct_medicationrequest, edw.dim_patient
                 (must be loaded first; see usp_nightly_quality_refresh for run order)

   Change log:
     2019-04-02  JD   Initial version
     2021-08-17  MK   Added BP LOINC codes per QI request (ticket #4471)
     2023-01-09  ??   Changed A1c window 12 -> 6 months
                      ** ALSO UPDATE dbo.usp_build_quality_measure_summary **
     2024-06-30  RT   Hotfix: A1c name match, added '%hemoglobin a1c%'
   ===================================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_build_patient_care_gaps
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DECLARE @reporting_as_of_date DATE;

        SELECT @reporting_as_of_date = MAX(activity_date)
        FROM (
            SELECT MAX(encounter_date) AS activity_date FROM edw.fct_encounter
            UNION ALL
            SELECT MAX(effective_date) FROM edw.fct_observation
            UNION ALL
            SELECT MAX(occurrence_date) FROM edw.fct_immunization WHERE is_completed_immunization = 1
        ) AS activity_dates;

        /* ---------- encounters ---------- */
        IF OBJECT_ID('tempdb..#encounter_activity') IS NOT NULL DROP TABLE #encounter_activity;

        SELECT
            patient_id,
            MAX(encounter_date) AS latest_encounter_date
        INTO #encounter_activity
        FROM edw.fct_encounter
        GROUP BY patient_id;

        /* ---------- observations ---------- */
        /* TODO: confirm BP codes with QI, not sure these are right (MK 2021) */
        IF OBJECT_ID('tempdb..#observation_activity') IS NOT NULL DROP TABLE #observation_activity;

        SELECT
            patient_id,
            MAX(CASE
                WHEN LOWER(observation_name) LIKE '%blood pressure%'
                    OR observation_code IN ('85354-9', '8480-6', '8462-4')
                    THEN effective_date
            END) AS latest_blood_pressure_date,
            MAX(CASE
                WHEN LOWER(observation_name) LIKE '%a1c%'
                    OR LOWER(observation_name) LIKE '%hemoglobin a1c%'
                    OR observation_code IN ('4548-4', '17856-6')
                    THEN effective_date
            END) AS latest_diabetes_monitoring_date
        INTO #observation_activity
        FROM edw.fct_observation
        GROUP BY patient_id;

        /* ---------- conditions ---------- */
        IF OBJECT_ID('tempdb..#condition_activity') IS NOT NULL DROP TABLE #condition_activity;

        SELECT
            patient_id,
            MAX(CASE WHEN LOWER(condition_name) LIKE '%diabetes%' THEN 1 ELSE 0 END) AS has_diabetes
        INTO #condition_activity
        FROM edw.fct_condition
        GROUP BY patient_id;

        /* ---------- immunizations ---------- */
        IF OBJECT_ID('tempdb..#immunization_activity') IS NOT NULL DROP TABLE #immunization_activity;

        SELECT
            patient_id,
            MAX(occurrence_date) AS latest_immunization_date
        INTO #immunization_activity
        FROM edw.fct_immunization
        WHERE is_completed_immunization = 1
        GROUP BY patient_id;

        /* ---------- medications ---------- */
        IF OBJECT_ID('tempdb..#medication_activity') IS NOT NULL DROP TABLE #medication_activity;

        SELECT
            patient_id,
            MAX(CASE WHEN is_active_medication_request = 1 THEN 1 ELSE 0 END) AS has_active_medication_request
        INTO #medication_activity
        FROM edw.fct_medicationrequest
        GROUP BY patient_id;

        /* ---------- combine ---------- */
        IF OBJECT_ID('tempdb..#patient_gap_inputs') IS NOT NULL DROP TABLE #patient_gap_inputs;

        SELECT
            p.patient_id,
            p.gender,
            p.age_years,
            p.age_band,
            e.latest_encounter_date,
            o.latest_blood_pressure_date,
            o.latest_diabetes_monitoring_date,
            i.latest_immunization_date,
            ISNULL(c.has_diabetes, 0) AS has_diabetes,
            ISNULL(m.has_active_medication_request, 0) AS has_active_medication_request
        INTO #patient_gap_inputs
        FROM edw.dim_patient AS p
        LEFT JOIN #encounter_activity    AS e ON p.patient_id = e.patient_id
        LEFT JOIN #observation_activity  AS o ON p.patient_id = o.patient_id
        LEFT JOIN #condition_activity    AS c ON p.patient_id = c.patient_id
        LEFT JOIN #immunization_activity AS i ON p.patient_id = i.patient_id
        LEFT JOIN #medication_activity   AS m ON p.patient_id = m.patient_id;

        /* ---------- reload target ---------- */
        BEGIN TRANSACTION;

        TRUNCATE TABLE rpt.patient_care_gaps;

        INSERT INTO rpt.patient_care_gaps (
            patient_id, gender, age_years, age_band,
            care_gap_code, care_gap_name, latest_relevant_event_date,
            care_gap_status, care_gap_key
        )
        SELECT
            patient_id, gender, age_years, age_band,
            care_gap_code, care_gap_name, latest_relevant_event_date,
            'open',
            CONCAT(patient_id, '|', care_gap_code)
        FROM (

            SELECT patient_id, gender, age_years, age_band,
                'annual_wellness_visit' AS care_gap_code,
                'No encounter documented in the last 12 months' AS care_gap_name,
                latest_encounter_date AS latest_relevant_event_date
            FROM #patient_gap_inputs
            WHERE latest_encounter_date IS NULL
                OR DATEDIFF(MONTH, latest_encounter_date, @reporting_as_of_date) > 12

            UNION ALL

            SELECT patient_id, gender, age_years, age_band,
                'blood_pressure_observation',
                'Adult patient without blood pressure observation in the last 12 months',
                latest_blood_pressure_date
            FROM #patient_gap_inputs
            WHERE age_years >= 18
                AND (latest_blood_pressure_date IS NULL
                    OR DATEDIFF(MONTH, latest_blood_pressure_date, @reporting_as_of_date) > 12)

            UNION ALL

            /* A1c window: 6 months (was 12, see change log 2023-01-09) */
            SELECT patient_id, gender, age_years, age_band,
                'diabetes_monitoring',
                'Diabetes cohort without A1c observation in the last 6 months',
                latest_diabetes_monitoring_date
            FROM #patient_gap_inputs
            WHERE has_diabetes = 1
                AND (latest_diabetes_monitoring_date IS NULL
                    OR DATEDIFF(MONTH, latest_diabetes_monitoring_date, @reporting_as_of_date) > 6)

            UNION ALL

            SELECT patient_id, gender, age_years, age_band,
                'immunization_review',
                'No completed immunization documented in the last 12 months',
                latest_immunization_date
            FROM #patient_gap_inputs
            WHERE latest_immunization_date IS NULL
                OR DATEDIFF(MONTH, latest_immunization_date, @reporting_as_of_date) > 12

            UNION ALL

            SELECT patient_id, gender, age_years, age_band,
                'medication_follow_up',
                'Active medication request without encounter in the last 12 months',
                latest_encounter_date
            FROM #patient_gap_inputs
            WHERE has_active_medication_request = 1
                AND (latest_encounter_date IS NULL
                    OR DATEDIFF(MONTH, latest_encounter_date, @reporting_as_of_date) > 12)

        ) AS care_gaps;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
