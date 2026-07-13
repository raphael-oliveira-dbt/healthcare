with source as (
    select *
    from {{ source('raw_fhir_roliveira', 'raw_condition') }}
)

select
    json_value(payload, '$.id') as condition_id,
    json_value(payload, '$.subject.reference') as patient_reference,
    json_value(payload, '$.encounter.reference') as encounter_reference,
    json_value(payload, '$.clinicalStatus.coding[0].code') as clinical_status,
    json_value(payload, '$.verificationStatus.coding[0].code') as verification_status,
    json_value(payload, '$.code.coding[0].code') as condition_code,
    json_value(payload, '$.code.text') as condition_text,
    safe_cast(json_value(payload, '$.onsetDateTime') as timestamp) as onset_at,
    payload,
    _source_file,
    _batch_id,
    _loaded_at
from source
