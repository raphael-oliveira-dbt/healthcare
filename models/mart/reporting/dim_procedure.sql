select
    concat(
        coalesce(procedure_code_system, 'unknown'),
        '|',
        coalesce(procedure_code, 'unknown'),
        '|',
        coalesce(procedure_name, 'unknown')
    ) as procedure_key,
    procedure_code,
    procedure_code_system,
    procedure_code_display,
    procedure_name,
    procedure_text,
    procedure_category_code,
    procedure_category_display,
    count(distinct procedure_id) as procedure_count,
    count(distinct patient_id) as patient_count,
    min(performed_date) as first_performed_date,
    max(performed_date) as latest_performed_date
from {{ ref('fct_procedure') }}
group by
    procedure_code,
    procedure_code_system,
    procedure_code_display,
    procedure_name,
    procedure_text,
    procedure_category_code,
    procedure_category_display
