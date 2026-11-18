-- Audit question: "Why was this member flagged (or not) on a given date?"
-- Set the member below and preview. Every version of every care gap for that member is listed,
-- with when it was recorded and when it was superseded or closed.

{% set member_patient_id = '00953a86-434f-4866-ab0a-5a5a3ddc6bb2' %}

select
    patient_id,
    age_years,
    care_gap_code,
    care_gap_name,
    case when dbt_is_deleted = 'True' then 'Gap closed' else 'Gap open' end as gap_event,
    latest_relevant_event_date,
    format_timestamp('%Y-%m-%d %H:%M UTC', dbt_valid_from) as recorded_at,
    format_timestamp('%Y-%m-%d %H:%M UTC', dbt_valid_to) as superseded_at
from {{ ref('snap_patient_care_gaps') }}
where patient_id = '{{ member_patient_id }}'
order by care_gap_code, dbt_valid_from
