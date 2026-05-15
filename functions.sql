-- Calculate patient age from DOB
CREATE OR REPLACE FUNCTION fn_patient_age(p_dob IN DATE)
    RETURN NUMBER
IS
BEGIN
    RETURN TRUNC(MONTHS_BETWEEN(SYSDATE, p_dob) / 12);
END fn_patient_age;
/
 
-- Count appointments for a doctor in a given month
CREATE OR REPLACE FUNCTION fn_doctor_appt_count(
    p_doctor_id IN NUMBER,
    p_year      IN NUMBER,
    p_month     IN NUMBER
) RETURN NUMBER
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_count
      FROM appointments
     WHERE doctor_id = p_doctor_id
       AND EXTRACT(YEAR  FROM appt_date) = p_year
       AND EXTRACT(MONTH FROM appt_date) = p_month
       AND status NOT IN ('CANCELLED','NO_SHOW');
    RETURN v_count;
END fn_doctor_appt_count;
/
 
-- Get the most recent diagnosis for a patient
CREATE OR REPLACE FUNCTION fn_last_diagnosis(p_patient_id IN NUMBER)
    RETURN VARCHAR2
IS
    v_diagnosis VARCHAR2(500);
BEGIN
    SELECT diagnosis
      INTO v_diagnosis
      FROM (
          SELECT diagnosis
            FROM medical_records
           WHERE patient_id = p_patient_id
           ORDER BY visit_date DESC
      )
     WHERE ROWNUM = 1;
    RETURN v_diagnosis;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 'No records found';
END fn_last_diagnosis;
/
 
-- Check if a medication is in stock
CREATE OR REPLACE FUNCTION fn_is_in_stock(
    p_medication_id IN NUMBER,
    p_qty_needed    IN NUMBER
) RETURN VARCHAR2
IS
    v_stock NUMBER;
BEGIN
    SELECT stock_qty INTO v_stock FROM medications
     WHERE medication_id = p_medication_id;
    IF v_stock >= p_qty_needed THEN
        RETURN 'YES';
    ELSE
        RETURN 'NO';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 'MEDICATION_NOT_FOUND';
END fn_is_in_stock;
/
