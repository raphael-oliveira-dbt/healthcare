select
    patient_id,
    given_name,
    family_name,
    concat(coalesce(given_name, ''), case when given_name is not null and family_name is not null then ' ' else '' end, coalesce(family_name, '')) as patient_name,
    gender,
    birth_date,
    deceased_at,
    deceased_at is not null as is_deceased,
    date_diff(current_date(), birth_date, year) as age_years,
    case
        when date_diff(current_date(), birth_date, year) < 18 then '0-17'
        when date_diff(current_date(), birth_date, year) < 35 then '18-34'
        when date_diff(current_date(), birth_date, year) < 50 then '35-49'
        when date_diff(current_date(), birth_date, year) < 65 then '50-64'
        else '65+'
    end as age_band,
    _source_file,
    _batch_id,
    _loaded_at
from {{ ref('int_fhir_patient') }}

