-- Register a new patient
CREATE OR REPLACE PROCEDURE sp_register_patient (
    p_first_name      IN  VARCHAR2,
    p_last_name       IN  VARCHAR2,
    p_dob             IN  DATE,
    p_gender          IN  CHAR,
    p_blood_type      IN  VARCHAR2,
    p_phone           IN  VARCHAR2,
    p_email           IN  VARCHAR2,
    p_assigned_doctor IN  NUMBER,
    p_new_id          OUT NUMBER
)
IS
BEGIN
    INSERT INTO patients
        (first_name, last_name, date_of_birth, gender,
         blood_type, phone, email, assigned_doctor, admission_date)
    VALUES
        (p_first_name, p_last_name, p_dob, p_gender,
         p_blood_type, p_phone, p_email, p_assigned_doctor, SYSDATE)
    RETURNING patient_id INTO p_new_id;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_register_patient;
/
 
-- Schedule an appointment
CREATE OR REPLACE PROCEDURE sp_schedule_appointment (
    p_patient_id IN  NUMBER,
    p_doctor_id  IN  NUMBER,
    p_appt_date  IN  DATE,
    p_notes      IN  VARCHAR2 DEFAULT NULL,
    p_appt_id    OUT NUMBER
)
IS
BEGIN
    INSERT INTO appointments
        (patient_id, doctor_id, appt_date, notes, status)
    VALUES
        (p_patient_id, p_doctor_id, p_appt_date, p_notes, 'SCHEDULED')
    RETURNING appt_id INTO p_appt_id;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_schedule_appointment;
/
 
-- Add a medical record after a visit
CREATE OR REPLACE PROCEDURE sp_add_medical_record (
    p_patient_id IN NUMBER,
    p_doctor_id  IN NUMBER,
    p_diagnosis  IN VARCHAR2,
    p_treatment  IN VARCHAR2,
    p_severity   IN VARCHAR2 DEFAULT 'MODERATE',
    p_follow_up  IN DATE     DEFAULT NULL,
    p_notes      IN CLOB     DEFAULT NULL,
    p_record_id  OUT NUMBER
)
IS
BEGIN
    INSERT INTO medical_records
        (patient_id, doctor_id, visit_date,
         diagnosis, treatment, severity, follow_up, notes)
    VALUES
        (p_patient_id, p_doctor_id, SYSDATE,
         p_diagnosis, p_treatment, p_severity, p_follow_up, p_notes)
    RETURNING record_id INTO p_record_id;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_add_medical_record;
/
 
-- Issue a prescription
CREATE OR REPLACE PROCEDURE sp_issue_prescription (
    p_patient_id    IN  NUMBER,
    p_doctor_id     IN  NUMBER,
    p_medication_id IN  NUMBER,
    p_dosage_qty    IN  NUMBER,
    p_duration_days IN  NUMBER,
    p_instructions  IN  VARCHAR2 DEFAULT NULL,
    p_rx_id         OUT NUMBER
)
IS
    v_stock_ok VARCHAR2(30);
BEGIN
    v_stock_ok := fn_is_in_stock(p_medication_id, p_dosage_qty);
    IF v_stock_ok != 'YES' THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Insufficient stock for medication ID ' || p_medication_id);
    END IF;
 
    INSERT INTO prescriptions
        (patient_id, doctor_id, medication_id,
         dosage_qty, duration_days, instructions, prescribed_date)
    VALUES
        (p_patient_id, p_doctor_id, p_medication_id,
         p_dosage_qty, p_duration_days, p_instructions, SYSDATE)
    RETURNING prescription_id INTO p_rx_id;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_issue_prescription;
/
 
-- Cancel an appointment
CREATE OR REPLACE PROCEDURE sp_cancel_appointment (
    p_appt_id IN NUMBER
)
IS
    v_status appointments.status%TYPE;
BEGIN
    SELECT status INTO v_status FROM appointments WHERE appt_id = p_appt_id;
 
    IF v_status IN ('COMPLETED','CANCELLED') THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Appointment ' || p_appt_id || ' cannot be cancelled (status: ' || v_status || ').');
    END IF;
 
    UPDATE appointments
       SET status = 'CANCELLED'
     WHERE appt_id = p_appt_id;
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20004, 'Appointment ' || p_appt_id || ' not found.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_cancel_appointment;
/

-- update severity
CREATE OR REPLACE PROCEDURE sp_update_severity (
    p_patient_id IN NUMBER,
    p_diagnosis  IN VARCHAR2
) IS
    CURSOR c_records IS
        SELECT record_id, severity
        FROM medical_records
        WHERE patient_id = p_patient_id
          AND diagnosis  = p_diagnosis;
    v_updated NUMBER := 0;
BEGIN
    FOR r IN c_records LOOP
        -- Multi-level upgrade logic
        IF r.severity = 'MILD' THEN
            UPDATE medical_records SET severity = 'MODERATE' WHERE record_id = r.record_id;
            v_updated := v_updated + 1;
        ELSIF r.severity = 'MODERATE' THEN
            UPDATE medical_records SET severity = 'SEVERE' WHERE record_id = r.record_id;
            v_updated := v_updated + 1;
        ELSIF r.severity = 'SEVERE' THEN
            UPDATE medical_records SET severity = 'CRITICAL' WHERE record_id = r.record_id;
            v_updated := v_updated + 1;
        END IF;
    END LOOP;

    -- Cleanup logic: Delete MILD records that are now redundant 
    DELETE FROM medical_records
    WHERE patient_id = p_patient_id
      AND severity = 'MILD'
      AND record_id NOT IN (
          SELECT record_id FROM medical_records
          WHERE patient_id = p_patient_id AND severity != 'MILD'
      );

    -- Log the change in the audit table
    INSERT INTO patient_audit_log (patient_id, changed_by, change_date)
    VALUES (p_patient_id, USER, SYSDATE);
    
    COMMIT;
END sp_update_severity;
/