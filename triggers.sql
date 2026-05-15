-- Prevent double-booking a doctor at the same time slot
CREATE OR REPLACE TRIGGER trg_no_double_booking
    BEFORE INSERT OR UPDATE ON appointments
    FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_count
      FROM appointments
     WHERE doctor_id = :NEW.doctor_id
       AND appt_date = :NEW.appt_date
       AND status    NOT IN ('CANCELLED','NO_SHOW')
       AND appt_id  != NVL(:NEW.appt_id, -1);
 
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Doctor ' || :NEW.doctor_id || ' already has an appointment at this time.');
    END IF;
END;
/

-- Update medication stock when a prescription is inserted
CREATE OR REPLACE TRIGGER trg_reduce_stock
    AFTER INSERT ON prescriptions
    FOR EACH ROW
BEGIN
    UPDATE medications
       SET stock_qty  = stock_qty - :NEW.dosage_qty,
           updated_at = SYSDATE
     WHERE medication_id = :NEW.medication_id;
END;
/
 
-- Audit: log updates to patients
CREATE TABLE patient_audit_log (
    log_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id  NUMBER,
    changed_by  VARCHAR2(100),
    change_date DATE DEFAULT SYSDATE,
    old_email   VARCHAR2(100),
    new_email   VARCHAR2(100),
    old_phone   VARCHAR2(20),
    new_phone   VARCHAR2(20)
);
 
CREATE OR REPLACE TRIGGER trg_patient_audit
    AFTER UPDATE OF email, phone ON patients
    FOR EACH ROW
BEGIN
    INSERT INTO patient_audit_log
        (patient_id, changed_by, old_email, new_email, old_phone, new_phone)
    VALUES
        (:OLD.patient_id, USER, :OLD.email, :NEW.email, :OLD.phone, :NEW.phone);
END;
/