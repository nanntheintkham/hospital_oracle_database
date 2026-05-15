# Hospital Management — Oracle Database

An Oracle 11g database project modeling a hospital's day-to-day operations: patients, doctors, departments, appointments, prescriptions, medications, and medical records. Includes the full schema, supporting PL/SQL (procedures, functions, triggers), reporting views, indexes, range-partitioned tables, and sample CSV data for loading.

Designed and built with Oracle SQL Developer Data Modeler 24.3.

## Schema overview

Seven base tables plus an audit table, all wired together with foreign keys, check constraints, and identity sequences/triggers.

| Table              | Purpose                                                     |
|--------------------|-------------------------------------------------------------|
| `patients`         | Patient demographics, contact info, assigned doctor. Range-partitioned by `admission_date` (pre-2022, 2022, 2023, 2024, 2025+). |
| `doctors`          | Doctor records, specialization, license, department membership. |
| `departments`      | Hospital departments and their head doctor.                 |
| `appointments`     | Scheduled visits with status (`SCHEDULED`/`COMPLETED`/`CANCELLED`/`NO_SHOW`) and a duration check (15/30/45/60 min). |
| `medical_records`  | Diagnosis, treatment, severity, follow-up. Index-organized table (`ORGANIZATION INDEX`). |
| `medications`      | Drug catalog with category, unit price, stock quantity.     |
| `prescriptions`    | Patient–doctor–medication links with dosage, duration, instructions. |
| `patient_audit_log`| Auto-populated audit of email/phone changes on `patients`.  |

Diagram: see `Relational_2.png` for the ERD and `partitions.png` for the partitioning layout.

## File layout

```
.
├── create_tables.ddl                       -- Tables, FKs, sequences, identity triggers, partitions
├── procedures.sql                          -- Stored procedures (patient/appt/record/Rx workflows)
├── functions.sql                           -- Helper functions (age, appt count, last diagnosis, stock)
├── triggers.sql                            -- Business-rule triggers + audit table & trigger
├── views.sql                               -- Reporting views (+ stats gather)
├── idx.sql                                 -- Secondary indexes for common queries
├── Relational_2.png                        -- ER diagram
├── partitions.png                          -- Patients table partitioning diagram
├── hospital_project_documentation.docx     -- Full project write-up
├── hospital_project_documentation_v2.docx  -- Revised write-up
├── hospital_project_documentation(LQOO56).pdf  -- PDF export of the documentation
└── *.csv                                   -- Seed data for each table
```

## PL/SQL surface

Stored procedures in `procedures.sql`:

- `sp_register_patient` — insert a new patient, return generated ID
- `sp_schedule_appointment` — book an appointment (defaults status to `SCHEDULED`)
- `sp_add_medical_record` — record a visit with diagnosis/treatment/severity
- `sp_issue_prescription` — validates stock via `fn_is_in_stock` before issuing
- `sp_cancel_appointment` — guards against cancelling completed/already-cancelled appts
- `sp_update_severity` — bulk-escalate severity for a patient/diagnosis, with cleanup and audit logging

Functions in `functions.sql`:

- `fn_patient_age(dob)` — years since DOB
- `fn_doctor_appt_count(doctor_id, year, month)` — completed/scheduled appts in a month
- `fn_last_diagnosis(patient_id)` — most recent diagnosis text
- `fn_is_in_stock(medication_id, qty_needed)` — `YES` / `NO` / `MEDICATION_NOT_FOUND`

Triggers in `triggers.sql`:

- `trg_no_double_booking` — rejects two non-cancelled appointments for the same doctor at the same `appt_date`
- `trg_reduce_stock` — decrements `medications.stock_qty` after each prescription insert
- `trg_patient_audit` — logs email/phone changes to `patient_audit_log`
- Identity triggers (`*_id_trg`) auto-populate primary keys from sequences

## Views

Defined in `views.sql`:

- `vw_patient_details` — active patients joined with their doctor and department
- `vw_todays_appointments` — appointments where `TRUNC(appt_date) = TRUNC(SYSDATE)`
- `vw_department_stats` — doctor/patient/appointment counts per department
- `vw_low_stock_medications` — medications with `stock_qty < 100`
- `vw_prescription_history` — flattened patient–doctor–medication prescription log

## Indexes

`idx.sql` adds B-tree indexes for common access paths:

- Patients: `(last_name, first_name)`, `date_of_birth`, `assigned_doctor`
- Appointments: `appt_date`, `patient_id`, `(doctor_id, status)`
- Medical records: `(patient_id, visit_date DESC)`, `severity`
- Prescriptions: `patient_id`, `medication_id`
- Medications: `category`

Note: `views.sql` also creates `idx_patients_doctor` and `idx_appts_doctor_status` (overlap with `idx.sql`). Run one or the other — Oracle will error on duplicates if both are run as-is.

## How to run

Tested on Oracle Database 11g. Run as a schema owner (the documentation references schema `LQOO56`).

```sql
-- 1. Schema and key generators
@create_tables.ddl

-- 2. Business logic
@functions.sql
@procedures.sql
@triggers.sql

-- 3. Reporting layer
@views.sql
@idx.sql
```

### Loading the sample data

The CSVs use the column order of their target tables. Load them with SQL*Loader, External Tables, or SQL Developer's Import Data wizard. Suggested load order to respect foreign keys:

1. `departments` (no CSV — create rows manually or as part of seeding)
2. `doctors.csv`
3. `medications.csv`
4. `patients.csv`
5. `appointments.csv`
6. `prescriptions.csv`
7. `medical_records.csv`

## Documentation

Full write-up of design decisions, ER reasoning, partitioning rationale, and query examples lives in `hospital_project_documentation.docx` (and the PDF export).

## License

No license specified. All rights reserved by the author unless a license is added later.
