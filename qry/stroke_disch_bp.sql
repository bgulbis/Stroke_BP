WITH PATIENTS AS (
	SELECT DISTINCT
		ENCOUNTER.ENCNTR_ID,
		ENCOUNTER.PERSON_ID,
		ENCNTR_ALIAS.ALIAS,
		ENCOUNTER.DISCH_DT_TM
	FROM
		ENCNTR_ALIAS,
		ENCOUNTER
	WHERE
	    ENCNTR_ALIAS.ALIAS IN @prompt('Enter value(s) for Alias','A',,Multi,Free,Persistent,,User:0)
		AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
		AND ENCNTR_ALIAS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
), SBP AS (
	SELECT DISTINCT
		PATIENTS.ALIAS,
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS EVENT_DATETIME,
		TRUNC(pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER'))))) AS EVENT_DATE,
		CLINICAL_EVENT.EVENT_ID,
		CLINICAL_EVENT.EVENT_CD,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS EVENT,
		TO_NUMBER(CLINICAL_EVENT.RESULT_VAL) AS RESULT_VAL
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
		AND CLINICAL_EVENT.EVENT_END_DT_TM <= PATIENTS.DISCH_DT_TM
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
)

SELECT * FROM SBP
/* SELECT
	ALIAS AS FIN,
	EVENT_DATE,
	MIN(RESULT_VAL) AS MIN_SBP,
	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY EVENT_END_DT_TM, EVENT_ID) OVER (PARTITION BY ALIAS, EVENT_DATE) "LOWER_IQR",
	MEDIAN(RESULT_VAL) AS MEDIAN_SBP,
	-- PERCENT_RANK(RESULT_VAL, 75) WITHIN GROUP AS UPPER_IQR,
	MAX(RESULT_VAL) AS MAX_SBP
FROM
	SBP
GROUP BY
	ALIAS,
	EVENT_DATE
 */