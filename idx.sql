-- Patients: common search columns
CREATE INDEX idx_patients_name       ON patients(last_name, first_name);
CREATE INDEX idx_patients_dob        ON patients(date_of_birth);
CREATE INDEX idx_patients_doctor     ON patients(assigned_doctor);
 
-- Appointments: date-range lookups + status filter
CREATE INDEX idx_appts_date          ON appointments(appt_date);
CREATE INDEX idx_appts_patient       ON appointments(patient_id);
CREATE INDEX idx_appts_doctor_status ON appointments(doctor_id, status);
 
-- Medical records: patient history queries
CREATE INDEX idx_records_patient     ON medical_records(patient_id, visit_date DESC);
CREATE INDEX idx_records_severity    ON medical_records(severity);
 
-- Prescriptions: patient & medication lookups
CREATE INDEX idx_rx_patient          ON prescriptions(patient_id);
CREATE INDEX idx_rx_medication       ON prescriptions(medication_id);
 
-- Medications: category search
CREATE INDEX idx_meds_category       ON medications(category);