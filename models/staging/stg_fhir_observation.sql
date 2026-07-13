with source as (
    select *
    from {{ source('raw_fhir_roliveira', 'raw_observation') }}
)

select
    json_value(payload, '$.id') as observation_id,
    json_value(payload, '$.subject.reference') as patient_reference,
    json_value(payload, '$.encounter.reference') as encounter_reference,
    json_value(payload, '$.status') as observation_status,
    json_value(payload, '$.code.coding[0].code') as observation_code,
    json_value(payload, '$.code.text') as observation_text,
    safe_cast(json_value(payload, '$.effectiveDateTime') as timestamp) as effective_at,
    safe_cast(json_value(payload, '$.valueQuantity.value') as numeric) as value_quantity,
    json_value(payload, '$.valueQuantity.unit') as value_unit,
    payload,
    _source_file,
    _batch_id,
    _loaded_at
from source
