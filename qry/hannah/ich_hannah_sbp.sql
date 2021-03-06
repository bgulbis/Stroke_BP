WITH PATIENTS AS (
	SELECT DISTINCT
		ENCOUNTER.ENCNTR_ID,
		ENCOUNTER.PERSON_ID,
		ENCNTR_ALIAS.ALIAS,
		ENCOUNTER.ARRIVE_DT_TM,
		ENCOUNTER.REG_DT_TM,
		ENCOUNTER.DISCH_DT_TM
	FROM
		ENCNTR_ALIAS,
		ENCOUNTER
	WHERE
	    ENCNTR_ALIAS.ALIAS IN @prompt('Enter value(s) for Alias','A',,Multi,Free,Persistent,,User:0)
		AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
		AND ENCNTR_ALIAS.ACTIVE_IND = 1
		AND ENCNTR_ALIAS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
)

SELECT DISTINCT
	PATIENTS.ENCNTR_ID,
	PATIENTS.ALIAS AS FIN,
	TO_CHAR(pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago'), 'YYYY-MM-DD"T"HH24:MI:SS') AS VITAL_DATETIME,
	CLINICAL_EVENT.EVENT_ID,
	pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS VITAL,
	CLINICAL_EVENT.RESULT_VAL,
	TO_CHAR(pi_from_gmt(PATIENTS.ARRIVE_DT_TM, 'America/Chicago'), 'YYYY-MM-DD"T"HH24:MI:SS') AS ARRIVE_DATETIME,
	TO_CHAR(pi_from_gmt(PATIENTS.REG_DT_TM, 'America/Chicago'), 'YYYY-MM-DD"T"HH24:MI:SS') AS ADMIT_DATETIME,
	TO_CHAR(pi_from_gmt(PATIENTS.DISCH_DT_TM, 'America/Chicago'), 'YYYY-MM-DD"T"HH24:MI:SS') AS DISCH_DATETIME
FROM
	CLINICAL_EVENT,
	PATIENTS
WHERE
	PATIENTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
	AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
	AND PATIENTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
	AND CLINICAL_EVENT.EVENT_CD IN (
		30098, -- Systolic Blood Pressure
		134401648 -- Arterial Systolic BP 1
	)
	AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'	
