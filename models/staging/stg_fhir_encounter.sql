with source as (
    select *
    from {{ source('raw_fhir_roliveira', 'raw_encounter') }}
)

select
    json_value(payload, '$.id') as encounter_id,
    json_value(payload, '$.subject.reference') as patient_reference,
    json_value(payload, '$.status') as encounter_status,
    json_value(payload, '$.class.code') as encounter_class_code,
    safe_cast(json_value(payload, '$.period.start') as timestamp) as encounter_start_at,
    safe_cast(json_value(payload, '$.period.end') as timestamp) as encounter_end_at,
    payload,
    _source_file,
    _batch_id,
    _loaded_at
from source
