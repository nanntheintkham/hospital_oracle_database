-- Full patient info with doctor name
CREATE OR REPLACE VIEW vw_patient_details AS
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name          AS patient_name,
    p.date_of_birth,
    TRUNC(MONTHS_BETWEEN(SYSDATE, p.date_of_birth) / 12) AS age,
    p.gender,
    p.blood_type,
    p.phone,
    p.email,
    p.admission_date,
    d.first_name || ' ' || d.last_name          AS doctor_name,
    d.specialization,
    dept.dept_name
FROM patients    p
JOIN doctors     d    ON p.assigned_doctor = d.doctor_id
JOIN departments dept ON d.dept_id         = dept.dept_id
WHERE p.is_active = 'Y';
 
-- Today's appointment schedule
CREATE OR REPLACE VIEW vw_todays_appointments AS
SELECT
    a.appt_id,
    a.appt_date,
    p.first_name || ' ' || p.last_name  AS patient_name,
    d.first_name || ' ' || d.last_name  AS doctor_name,
    d.specialization,
    a.status,
    a.notes
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors  d ON a.doctor_id  = d.doctor_id
WHERE TRUNC(a.appt_date) = TRUNC(SYSDATE)
ORDER BY a.appt_date;
 
CREATE INDEX idx_patients_doctor ON patients(assigned_doctor);
CREATE INDEX idx_appts_doctor_status ON appointments(doctor_id, status);

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS('LQOO56', 'PATIENTS');
  DBMS_STATS.GATHER_TABLE_STATS('LQOO56', 'APPOINTMENTS');
  DBMS_STATS.GATHER_TABLE_STATS('LQOO56', 'DOCTORS');
END;
/
 
-- Department statistics
CREATE OR REPLACE VIEW vw_department_stats AS
SELECT
    dept.dept_id,
    dept.dept_name,
    COUNT(DISTINCT d.doctor_id)    AS total_doctors,
    COUNT(DISTINCT p.patient_id)   AS total_patients,
    COUNT(DISTINCT a.appt_id)      AS total_appointments
FROM departments dept
LEFT JOIN doctors      d ON d.dept_id        = dept.dept_id
LEFT JOIN patients     p ON p.assigned_doctor = d.doctor_id
LEFT JOIN appointments a ON a.doctor_id       = d.doctor_id
GROUP BY dept.dept_id, dept.dept_name;
 
-- Medication stock alert (low stock)
CREATE OR REPLACE VIEW vw_low_stock_medications AS
SELECT
    medication_id,
    med_name,
    category,
    stock_qty,
    unit
FROM medications
WHERE stock_qty < 100
ORDER BY stock_qty ASC;
 
-- Patient prescription history
CREATE OR REPLACE VIEW vw_prescription_history AS
SELECT
    rx.prescription_id,
    p.first_name || ' ' || p.last_name  AS patient_name,
    d.first_name || ' ' || d.last_name  AS doctor_name,
    m.med_name,
    m.category,
    rx.dosage_qty || ' ' || m.unit      AS dosage,
    rx.duration_days,
    rx.prescribed_date,
    rx.instructions
FROM prescriptions rx
JOIN patients   p ON rx.patient_id   = p.patient_id
JOIN doctors    d ON rx.doctor_id    = d.doctor_id
JOIN medications m ON rx.medication_id = m.medication_id
ORDER BY rx.prescribed_date DESC;