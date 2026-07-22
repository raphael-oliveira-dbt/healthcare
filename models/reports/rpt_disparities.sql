select
    concat(measure_id, '|', coalesce(gender, 'unknown'), '|', coalesce(age_band, 'unknown')) as disparities_report_key,
    measure_id,
    measure_name,
    gender,
    age_band,
    denominator_count,
    numerator_count,
    performance_rate,
    performance_rate - avg(performance_rate) over (partition by measure_id) as rate_difference_from_measure_average
from {{ ref('agg_quality_measure_summary') }}
where denominator_count > 0
