with source as (
    select *
    from {{ source('raw_fhir_roliveira', 'raw_procedure') }}
)

select
    json_value(payload, '$.id') as procedure_id,
    json_value(payload, '$.subject.reference') as patient_reference,
    json_value(payload, '$.encounter.reference') as encounter_reference,
    json_value(payload, '$.status') as procedure_status,
    json_value(payload, '$.code.coding[0].code') as procedure_code,
    json_value(payload, '$.code.text') as procedure_text,
    safe_cast(json_value(payload, '$.performedDateTime') as timestamp) as performed_at,
    safe_cast(json_value(payload, '$.performedPeriod.start') as timestamp) as performed_period_start_at,
    safe_cast(json_value(payload, '$.performedPeriod.end') as timestamp) as performed_period_end_at,
    payload,
    _source_file,
    _batch_id,
    _loaded_at
from source
