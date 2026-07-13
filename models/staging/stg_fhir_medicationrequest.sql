with source as (
    select *
    from {{ source('raw_fhir_roliveira', 'raw_medicationrequest') }}
)

select
    json_value(payload, '$.id') as medication_request_id,
    json_value(payload, '$.subject.reference') as patient_reference,
    json_value(payload, '$.encounter.reference') as encounter_reference,
    json_value(payload, '$.status') as medication_request_status,
    json_value(payload, '$.intent') as medication_request_intent,
    json_value(payload, '$.medicationCodeableConcept.coding[0].code') as medication_code,
    json_value(payload, '$.medicationCodeableConcept.text') as medication_text,
    safe_cast(json_value(payload, '$.authoredOn') as timestamp) as authored_at,
    payload,
    _source_file,
    _batch_id,
    _loaded_at
from source
