-- Audit question: "When did care gaps open or close, and how many were affected by each change?"
-- Each row is a moment the care-gap snapshot recorded a change. Pair the timestamp with git history
-- on seeds/hedis_measure_definitions.csv to show exactly which rule change caused it and who approved it.

select
    format_timestamp('%Y-%m-%d %H:%M UTC', dbt_valid_from) as recorded_at,
    care_gap_code,
    case when dbt_is_deleted = 'True' then 'Gap closed' else 'Gap open' end as gap_event,
    count(*) as gaps
from {{ ref('snap_patient_care_gaps') }}
group by 1, 2, 3
order by 1, 2, 3
