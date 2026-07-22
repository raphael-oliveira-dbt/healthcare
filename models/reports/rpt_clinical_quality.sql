select
    quality_measure_key as clinical_quality_report_key,
    measure_id,
    measure_name,
    gender,
    age_band,
    denominator_count,
    numerator_count,
    gap_count,
    performance_rate
from {{ ref('agg_quality_measure_summary') }}
