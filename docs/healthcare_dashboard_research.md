# Healthcare Dashboard Research

This project models FHIR-backed patient, encounter, condition, observation, immunization, medication request, and procedure data. The dashboard/reporting layer should therefore focus on operationally useful clinical analytics that can be built without adding new source feeds.

## External anchors

- CMS electronic clinical quality measures and the CMS Measures Inventory are useful references for clinical quality dashboard concepts such as preventive screenings, chronic condition monitoring, and denominator/numerator framing.
- NCQA HEDIS is a useful reference for common managed-care reporting themes including immunization, access, chronic disease management, and medication management.
- AHRQ's National Healthcare Quality and Disparities Report is a useful reference for stratifying quality measures by demographic groups to identify differences in care delivery and outcomes.
- CDC public health and immunization reporting patterns are useful references for population health views by time, age, and demographic segment.
- HL7 FHIR resource definitions support this project's grains: Patient for demographics, Encounter for utilization, Condition for diagnoses/problems, Observation for labs/vitals/results, Immunization for vaccine events, MedicationRequest for orders, and Procedure for performed services.

## Dashboard candidates

| Dashboard | Primary question | Current mart coverage |
| --- | --- | --- |
| Population overview | What does the attributed patient population look like by age, gender, and mortality status? | `dim_patient`, `agg_patient_clinical_profile` |
| Encounter utilization | How is care utilization changing by month and demographic segment? | `fct_encounter`, `agg_monthly_clinical_activity` |
| Chronic conditions | Which diagnosed conditions affect the most patients, and which cohorts have active or confirmed diagnoses? | `fct_condition`, `dim_condition` |
| Clinical quality | What percent of eligible patients have recent encounters, BP observations, diabetes monitoring, and immunization documentation? | `agg_quality_measure_summary` |
| Preventive care gaps | Which patients appear to be missing recent wellness, blood pressure, diabetes monitoring, immunization review, or medication follow-up activity? | `agg_patient_care_gaps` |
| Immunization coverage | Which vaccines are documented over time and across demographic groups? | `fct_immunization` |
| Medication orders | Which medication orders are active, ordered, or discontinued by medication and cohort? | `fct_medicationrequest`, `dim_medication` |
| Procedure volume | Which completed procedures are most common and how does procedure volume trend over time? | `fct_procedure`, `dim_procedure` |
| Observation trends | How do numeric clinical results trend by observation type and cohort? | `fct_observation`, `dim_observation` |
| Safety signals | Which cohorts have abnormal results, active medication orders, or active conditions requiring follow-up? | `fct_observation`, `fct_medicationrequest`, `fct_condition` |
| High-risk cohorts | Which patients combine utilization, chronic condition, abnormal result, and care-gap signals? | `agg_patient_clinical_profile`, `agg_patient_care_gaps` |
| Disparities | Do quality rates vary materially across age and gender cohorts? | `agg_quality_measure_summary` |

## Scope notes

- These are analytics/demo reports, not certified regulatory quality measure submissions.
- Demographic stratification is limited to fields already modeled in `dim_patient`: `gender`, `age_years`, `age_band`, and `is_deceased`.
- Care gaps are heuristic indicators based on available FHIR events. They should be reviewed with clinical stakeholders before operational use.
- The reporting layer intentionally reuses existing atomic marts rather than adding intermediate models downstream of facts.
