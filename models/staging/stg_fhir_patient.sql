with source as (
    select *
    from {{ source('raw_fhir_roliveira', 'raw_patient') }}
)

select
    json_value(payload, '$.id') as patient_id,
    json_value(payload, '$.gender') as gender,
    safe_cast(json_value(payload, '$.birthDate') as date) as birth_date,
    safe_cast(json_value(payload, '$.deceasedDateTime') as timestamp) as deceased_at,
    json_value(payload, '$.name[0].family') as family_name,
    json_value(payload, '$.name[0].given[0]') as given_name,
    payload,
    _source_file,
    _batch_id,
    _loaded_at
from source
