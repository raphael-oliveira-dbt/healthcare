/* =====================================================================================
   Procedure:    dbo.usp_build_quality_measure_summary
   Purpose:      Rebuilds rpt.quality_measure_summary (measure x gender x age band rates)
                 Feeds the Power BI "Clinical Quality" and "Disparities" reports.
   Called by:    dbo.usp_nightly_quality_refresh  <-  Control-M job QUAL_NIGHTLY_04
   Depends on:   rpt.patient_clinical_profile (built by usp_build_patient_clinical_profile)
                 edw.fct_observation

   NOTE: BP and A1c logic copied from dbo.usp_build_patient_care_gaps.
         If you change one, change the other!!

   Change log:
     2019-05-14  JD   Initial version
     2021-08-17  MK   Added BP LOINC codes (ticket #4471)
     2023-01-09  ??   A1c window 12 -> 6 months
     2023-02-21  RT   Fixed: A1c window was still 12 here, didn't match care gaps report
                      (Q4 quality numbers reported to DHCS were off, see email thread)
   ===================================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_build_quality_measure_summary
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DECLARE @reporting_as_of_date DATE;

        SELECT @reporting_as_of_date = MAX(activity_date)
        FROM (
            SELECT MAX(latest_encounter_date) AS activity_date FROM rpt.patient_clinical_profile
            UNION ALL
            SELECT MAX(effective_date) FROM edw.fct_observation
            UNION ALL
            SELECT MAX(latest_immunization_date) FROM rpt.patient_clinical_profile
        ) AS activity_dates;

        /* ---------- patient flags ---------- */
        IF OBJECT_ID('tempdb..#patient_flags') IS NOT NULL DROP TABLE #patient_flags;

        SELECT
            patient_id,
            gender,
            age_years,
            age_band,
            has_diabetes,
            CASE
                WHEN latest_encounter_date IS NOT NULL
                    AND DATEDIFF(MONTH, latest_encounter_date, @reporting_as_of_date) <= 12
                    THEN 1 ELSE 0
            END AS has_recent_encounter,
            CASE
                WHEN latest_immunization_date IS NOT NULL
                    AND DATEDIFF(MONTH, latest_immunization_date, @reporting_as_of_date) <= 12
                    THEN 1 ELSE 0
            END AS has_recent_immunization
        INTO #patient_flags
        FROM rpt.patient_clinical_profile;

        /* ---------- observation flags (COPIED FROM usp_build_patient_care_gaps) ---------- */
        IF OBJECT_ID('tempdb..#observation_flags') IS NOT NULL DROP TABLE #observation_flags;

        SELECT
            patient_id,
            MAX(CASE
                WHEN (LOWER(observation_name) LIKE '%blood pressure%'
                        OR observation_code IN ('85354-9', '8480-6', '8462-4'))
                    AND DATEDIFF(MONTH, effective_date, @reporting_as_of_date) <= 12
                    THEN 1 ELSE 0
            END) AS has_recent_blood_pressure,
            MAX(CASE
                WHEN (LOWER(observation_name) LIKE '%a1c%'
                        OR LOWER(observation_name) LIKE '%hemoglobin a1c%'
                        OR observation_code IN ('4548-4', '17856-6'))
                    AND DATEDIFF(MONTH, effective_date, @reporting_as_of_date) <= 6
                    THEN 1 ELSE 0
            END) AS has_recent_diabetes_monitoring
        INTO #observation_flags
        FROM edw.fct_observation
        GROUP BY patient_id;

        /* ---------- measure inputs ---------- */
        IF OBJECT_ID('tempdb..#measure_inputs') IS NOT NULL DROP TABLE #measure_inputs;

        SELECT
            pf.patient_id,
            pf.gender,
            pf.age_years,
            pf.age_band,
            pf.has_recent_encounter,
            pf.has_recent_immunization,
            pf.has_diabetes,
            ISNULL(o.has_recent_blood_pressure, 0) AS has_recent_blood_pressure,
            ISNULL(o.has_recent_diabetes_monitoring, 0) AS has_recent_diabetes_monitoring
        INTO #measure_inputs
        FROM #patient_flags AS pf
        LEFT JOIN #observation_flags AS o
            ON pf.patient_id = o.patient_id;

        /* ---------- reload target ---------- */
        BEGIN TRANSACTION;

        TRUNCATE TABLE rpt.quality_measure_summary;

        INSERT INTO rpt.quality_measure_summary (
            measure_id, measure_name, gender, age_band, quality_measure_key,
            denominator_count, numerator_count, gap_count, performance_rate
        )
        SELECT
            measure_id,
            measure_name,
            gender,
            age_band,
            CONCAT(measure_id, '|', ISNULL(gender, 'unknown'), '|', ISNULL(age_band, 'unknown')),
            SUM(denominator_flag),
            SUM(numerator_flag),
            SUM(denominator_flag) - SUM(numerator_flag),
            ROUND(100.0 * SUM(numerator_flag) / NULLIF(SUM(denominator_flag), 0), 2)
        FROM (

            SELECT 'recent_encounter' AS measure_id,
                'Patients with encounter in last 12 months' AS measure_name,
                gender, age_band,
                1 AS denominator_flag,
                has_recent_encounter AS numerator_flag
            FROM #measure_inputs

            UNION ALL

            SELECT 'adult_blood_pressure',
                'Adults with blood pressure observation in last 12 months',
                gender, age_band,
                CASE WHEN age_years >= 18 THEN 1 ELSE 0 END,
                CASE WHEN age_years >= 18 THEN has_recent_blood_pressure ELSE 0 END
            FROM #measure_inputs

            UNION ALL

            SELECT 'diabetes_a1c_monitoring',
                'Diabetes cohort with A1c observation in last 6 months',
                gender, age_band,
                has_diabetes,
                CASE WHEN has_diabetes = 1 THEN has_recent_diabetes_monitoring ELSE 0 END
            FROM #measure_inputs

            UNION ALL

            SELECT 'recent_immunization_documentation',
                'Patients with completed immunization in last 12 months',
                gender, age_band,
                1,
                has_recent_immunization
            FROM #measure_inputs

        ) AS measure_rows
        GROUP BY measure_id, measure_name, gender, age_band;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
