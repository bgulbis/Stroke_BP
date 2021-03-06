WITH PATIENTS AS (
	SELECT DISTINCT
		ENCOUNTER.ENCNTR_ID,
		ENCOUNTER.PERSON_ID,
		ENCOUNTER.REG_DT_TM
	FROM
		DIAGNOSIS,
		ENCOUNTER,
		NOMENCLATURE,
		PERSON
	WHERE
		ENCOUNTER.ORGANIZATION_ID = 1 -- Memorial Hermann Hospital
		AND ENCOUNTER.REG_DT_TM BETWEEN 
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2017 00:00:00'}, User:0), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				), 
				pi_time_zone(1, @Variable('BOUSER'))
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'07/01/2020 00:00:00'}, User:1), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400, 
				pi_time_zone(1, @Variable('BOUSER'))
			)
		AND ENCOUNTER.LOC_FACILITY_CD = 3310 -- HH HERMANN
		-- AND ENCOUNTER.ADMIT_SRC_CD = 9061 -- Emergency Room
		AND ENCOUNTER.ENCNTR_ID = DIAGNOSIS.ENCNTR_ID
		AND DIAGNOSIS.DIAG_TYPE_CD = 26244 -- Final
		AND DIAGNOSIS.DIAG_PRIORITY = 1
		AND DIAGNOSIS.NOMENCLATURE_ID = NOMENCLATURE.NOMENCLATURE_ID
		AND REGEXP_INSTR(NOMENCLATURE.SOURCE_IDENTIFIER, '^I61|^I62') > 0
		AND NOMENCLATURE.SOURCE_VOCABULARY_CD = 641836527 -- ICD-10-CM
		AND NOMENCLATURE.PRINCIPLE_TYPE_CD = 751 -- Disease or Syndrome
		AND ENCOUNTER.PERSON_ID = PERSON.PERSON_ID
		AND TRUNC(((pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago')) - PERSON.BIRTH_DT_TM) / 365.25, 0) >= 18
), TFR_LOS AS (
	SELECT DISTINCT
		PATIENTS.ENCNTR_ID,
		ENCOUNTER.ENCNTR_ID AS TFR_ENCNTR_ID,
		ENCOUNTER.DISCH_DT_TM - ENCOUNTER.REG_DT_TM AS TFR_LOS,
		pi_get_cv_display(ENCOUNTER.LOC_FACILITY_CD) AS TFR_FACILITY,
		pi_get_cv_display(ENCOUNTER.ENCNTR_TYPE_CLASS_CD) AS TFR_ENCNTR_TYPE
	FROM
		ENCOUNTER,
		PATIENTS
	WHERE
		PATIENTS.PERSON_ID = ENCOUNTER.PERSON_ID
		AND ENCOUNTER.DISCH_DT_TM BETWEEN PATIENTS.REG_DT_TM - 1 AND PATIENTS.REG_DT_TM
		AND ENCOUNTER.ENCNTR_TYPE_CLASS_CD IN (
			42631, -- Inpatient
			55851, -- Emergency
			688523 -- Observation
		)
), TFR_COUNT AS (
	SELECT
		ENCNTR_ID,
		COUNT(DISTINCT TFR_ENCNTR_ID) AS NUM_PREV_ENCNTR
	FROM TFR_LOS
	GROUP BY ENCNTR_ID
), INCLUDE_PTS AS (
	SELECT *
	FROM PATIENTS
	WHERE PATIENTS.ENCNTR_ID NOT IN (SELECT ENCNTR_ID FROM TFR_COUNT WHERE NUM_PREV_ENCNTR > 1)
)

SELECT DISTINCT
	INCLUDE_PTS.ENCNTR_ID,
	ENCNTR_ALIAS.ALIAS AS FIN,
	ORDERS.ORIG_ORDER_DT_TM,
	pi_from_gmt(ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago') AS ORDER_DATETIME,
	ORDERS.ORDER_ID,
	pi_get_cv_display(ORDERS.CATALOG_CD) AS MEDICATION,
	ORDERS.ORDERED_AS_MNEMONIC,
	CASE ORDERS.ORIG_ORD_AS_FLAG WHEN 1 THEN 'Disch Rx' WHEN 2 THEN 'Home Med' END AS MED_TYPE
FROM
	ENCNTR_ALIAS,
	INCLUDE_PTS,
	ORDERS
WHERE
	INCLUDE_PTS.ENCNTR_ID = ORDERS.ENCNTR_ID
	AND ORDERS.ORIG_ORD_AS_FLAG IN (
		1, -- Prescription/Discharge Order
		2 -- Recorded/Home Medication
	)
	AND INCLUDE_PTS.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
	AND ENCNTR_ALIAS.ACTIVE_IND = 1