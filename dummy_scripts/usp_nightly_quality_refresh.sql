/* =====================================================================================
   Procedure:    dbo.usp_nightly_quality_refresh
   Purpose:      Master procedure for the nightly quality reporting refresh.
   Called by:    Control-M job QUAL_NIGHTLY_04 (scheduled 02:00, SLA 06:00)

   !!! RUN ORDER MATTERS !!!
   Each procedure reads tables loaded by the ones above it. Control-M only sees this
   one job, so if a step fails mid-way, downstream tables are left half-refreshed and
   nobody can see which reports are affected. Do not reorder without checking with
   the data team.

   No tests run here. If a source feed is late or a step loads bad data, the reports
   refresh anyway and the problem is usually found by a business user.

   Change log:
     2019-05-14  JD   Initial version
     2022-03-02  MK   Moved usp_build_patient_clinical_profile before quality summary
                      (summary was reading yesterday's profile, see incident INC-2291)
   ===================================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_nightly_quality_refresh
AS
BEGIN
    SET NOCOUNT ON;

    /* 1. Facts and dimensions (procedures not shown) */
    EXEC dbo.usp_load_dim_patient;
    EXEC dbo.usp_load_fct_encounter;
    EXEC dbo.usp_load_fct_observation;
    EXEC dbo.usp_load_fct_condition;
    EXEC dbo.usp_load_fct_immunization;
    EXEC dbo.usp_load_fct_medicationrequest;

    /* 2. Patient-level aggregates */
    EXEC dbo.usp_build_patient_clinical_profile;      /* must run before usp_build_quality_measure_summary */
    EXEC dbo.usp_build_patient_care_gaps;             /* bs/usp_build_patient_care_gaps.sql */

    /* 3. Quality reporting */
    EXEC dbo.usp_build_quality_measure_summary;       /* bs/usp_build_quality_measure_summary.sql */
    EXEC dbo.usp_build_rpt_clinical_quality;
    EXEC dbo.usp_build_rpt_disparities;
    EXEC dbo.usp_build_rpt_preventive_care_gaps;
    EXEC dbo.usp_build_rpt_high_risk_cohorts;
END;
GO
