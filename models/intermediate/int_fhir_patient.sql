select
    patient_id,
    gender,
    birth_date,
    deceased_at,
    family_name,
    given_name,
    payload,
    _source_file,
    _batch_id,
    _loaded_at
from {{ ref('stg_fhir_patient') }}
