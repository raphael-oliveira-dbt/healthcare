with source as (
    select *
    from {{ source('raw_fhir_roliveira', 'raw_immunization') }}
)

select
    json_value(payload, '$.id') as immunization_id,
    json_value(payload, '$.patient.reference') as patient_reference,
    json_value(payload, '$.encounter.reference') as encounter_reference,
    json_value(payload, '$.status') as immunization_status,
    json_value(payload, '$.vaccineCode.coding[0].code') as vaccine_code,
    json_value(payload, '$.vaccineCode.text') as vaccine_text,
    safe_cast(json_value(payload, '$.occurrenceDateTime') as timestamp) as occurrence_at,
    payload,
    _source_file,
    _batch_id,
    _loaded_at
from source
