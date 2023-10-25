

/* EMPLOYEE LEAVE AND ABSENTEEISM REPORT */

/*TITLE: EMPLOYEE LEAVE BALANCE AND ABSENTEEISM REPORT_DATE
  DATE : 25-JULY-2023
*/

/*ORGANIZATION*/

WITH ORGANIZATION AS
(
	SELECT 
		 HAOU.ORGANIZATION_ID
		,HAOU.EFFECTIVE_START_DATE
		,HAOU.EFFECTIVE_END_DATE
		,HAOUF.EFFECTIVE_END_DATE 					AS EFFECTIVE_END_DATE_TL
		,HAOUF.EFFECTIVE_START_DATE 				AS EFFECTIVE_START_DATE_TL
		,HAOUF.LANGUAGE
		,HAOUF.NAME									AS NAME
		,HAOUF.CREATION_DATE
		
	FROM
		 HR_ALL_ORGANIZATION_UNITS_F 				HAOU
		,HR_ORGANIZATION_UNITS_F_TL 				HAOUF
	WHERE
			HAOU.ORGANIZATION_ID 					= HAOUF.ORGANIZATION_ID(+)
		AND HAOU.EFFECTIVE_START_DATE 				= HAOUF.EFFECTIVE_START_DATE(+)
		AND HAOU.EFFECTIVE_END_DATE 				= HAOUF.EFFECTIVE_END_DATE(+)
		AND (USERENV('LANG')) 						= HAOUF.LANGUAGE(+)
		-- AND HAOU.ATTRIBUTE2                      ='Department'
		AND (TRUNC(SYSDATE) 						BETWEEN HAOU.EFFECTIVE_START_DATE AND HAOU.EFFECTIVE_END_DATE)
		AND (TRUNC(SYSDATE) 						BETWEEN HAOUF.EFFECTIVE_START_DATE(+) AND HAOUF.EFFECTIVE_END_DATE(+))
		AND (HAOUF.ORGANIZATION_ID 					IN (:P_DEPARTMENT) OR 'ALL' IN(:P_DEPARTMENT || 'ALL'))
)

/*ABSENCE DETAILS*/

,ABSENCE AS
(
SELECT 
	APAE.PERSON_ID
	,NVL(APAE.DURATION,0)																					AS DURATION
	,INITCAP(TO_CHAR( (APAE.START_DATE),'fmMON-YY','NLS_DATE_LANGUAGE = AMERICAN')) 						AS START_DATE
	,INITCAP(TO_CHAR( (APAE.START_DATE),'YYYY')) 															AS ORDER_YEAR
	,INITCAP(TO_CHAR( (APAE.START_DATE),'MM')) 																AS ORDER_MONTH
	,AATV.NAME 																								AS LEAVE
	,APAE.START_DATE																						AS START_D
	,APAE.END_DATE																							AS END_D

FROM
	 ANC_PER_ABS_ENTRIES 					APAE
	,ANC_ABSENCE_TYPES_VL 					AATV
	
WHERE 
		APAE.ABSENCE_TYPE_ID 	 			= AATV.ABSENCE_TYPE_ID(+)
	AND APAE.APPROVAL_STATUS_CD				IN ('APPROVED','AWAITING')
	AND APAE.ABSENCE_STATUS_CD				<> 'ORA_WITHDRAWN'
--  AND AATV.NAME 							IN ('Annual Leave','Annual Leave - Calendar Days') 
	AND TRUNC(SYSDATE) 						BETWEEN TRUNC(AATV.EFFECTIVE_START_DATE) 	AND TRUNC(AATV.EFFECTIVE_END_DATE)

)

/*MAIN QUERY*/
SELECT 
 DEPARTMENT
,NO_OF_STAFF
,PERIOD_START_DATE
,REPORT_DATE
,ORDER_YEAR
,ORDER_MONTH
,START_DATE
,END_DATE
,ANNUAL_LEAVE_DAYS
,OTHER_LEAVE_DAYS
,ANNUAL_LEAVE
,OTHER_LEAVE
,PERSON_NUMBER

FROM
(
SELECT 
	 ORGANIZATION.NAME 																						AS DEPARTMENT
	,LISTAGG(DISTINCT PAPF.PERSON_NUMBER,',') WITHIN GROUP 
	 (ORDER BY ABSENCE.START_DATE) OVER(PARTITION BY ORGANIZATION.NAME, ABSENCE.START_DATE) 				AS PERSON_NUMBER
	-- ,COUNT(PAPF.PERSON_ID) OVER (PARTITION BY PAAF.ORGANIZATION_ID)			 								AS NO_OF_STAFF
	,COUNT(DISTINCT ABSENCE.PERSON_ID) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE)			 		AS NO_OF_STAFF
	,ABSENCE.START_DATE																 						AS PERIOD_START_DATE
	,INITCAP(TO_CHAR( (SYSDATE),'DD-fmMON-YYYY','NLS_DATE_LANGUAGE = AMERICAN'))							AS REPORT_DATE
	,ABSENCE.ORDER_YEAR																						AS ORDER_YEAR
	,ABSENCE.ORDER_MONTH																					AS ORDER_MONTH
	,INITCAP(TO_CHAR((:P_FROM_DATE),'fmMON-YY','NLS_DATE_LANGUAGE = AMERICAN'))								AS START_DATE
	,INITCAP(TO_CHAR((:P_TO_DATE),'fmMON-YY','NLS_DATE_LANGUAGE = AMERICAN'))								AS END_DATE
	,NVL (ROUND((SUM(CASE WHEN ABSENCE.LEAVE IN ('Annual Leave','Annual Leave - Calendar Days') 					THEN NVL(ABSENCE.DURATION,0) END) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE)),2),0) AS ANNUAL_LEAVE_DAYS
	,NVL (ROUND((SUM(CASE WHEN ABSENCE.LEAVE NOT IN ('Annual Leave','Annual Leave - Calendar Days') 				THEN NVL(ABSENCE.DURATION,0) END) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE)),2),0) AS OTHER_LEAVE_DAYS
	,NVL (ROUND(((NVL((SUM(CASE WHEN ABSENCE.LEAVE IN ('Annual Leave','Annual Leave - Calendar Days') 		THEN NVL(ABSENCE.DURATION,0) END) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE)),0))/(DECODE((COUNT(DISTINCT ABSENCE.PERSON_ID) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE)),0,NULL,(COUNT(DISTINCT ABSENCE.PERSON_ID) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE))))),2),0) ANNUAL_LEAVE
	,NVL (ROUND(((NVL((SUM(CASE WHEN ABSENCE.LEAVE NOT IN ('Annual Leave','Annual Leave - Calendar Days') 	THEN NVL(ABSENCE.DURATION,0) END) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE)),0))/(DECODE((COUNT(DISTINCT ABSENCE.PERSON_ID) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE)),0,NULL,(COUNT(DISTINCT ABSENCE.PERSON_ID) OVER (PARTITION BY PAAF.ORGANIZATION_ID, ABSENCE.START_DATE))))),2),0) OTHER_LEAVE

FROM
	 PER_ALL_PEOPLE_F           			PAPF
	,PER_PERSON_NAMES_F         			PPNF
	,PER_ALL_ASSIGNMENTS_F      			PAAF
	,ORGANIZATION							ORGANIZATION
	,ABSENCE								ABSENCE
	
WHERE  
		PAPF.PERSON_ID           			= PPNF.PERSON_ID
	AND PAPF.PERSON_ID           			= PAAF.PERSON_ID
	AND PAAF.ORGANIZATION_ID                = ORGANIZATION.ORGANIZATION_ID
	AND PAPF.PERSON_ID                		= ABSENCE.PERSON_ID
	AND PPNF.NAME_TYPE                      = 'GLOBAL'	
	AND PAAF.PRIMARY_FLAG                   = 'Y'
	AND PAAF.ASSIGNMENT_STATUS_TYPE         = 'ACTIVE'
	AND PAAF.PRIMARY_ASSIGNMENT_FLAG        = 'Y'
	AND TRUNC(SYSDATE) 						BETWEEN TRUNC(PAPF.EFFECTIVE_START_DATE )  AND TRUNC(PAPF.EFFECTIVE_END_DATE )
	AND TRUNC(SYSDATE) 						BETWEEN TRUNC(PAAF.EFFECTIVE_START_DATE)  AND TRUNC(PAAF.EFFECTIVE_END_DATE)
	AND ABSENCE.START_D 					>= NVL (:P_FROM_DATE,ABSENCE.START_D)
	AND ABSENCE.END_D 						<= NVL (:P_TO_DATE,ABSENCE.END_D)
)
GROUP BY
 DEPARTMENT
,NO_OF_STAFF
,PERIOD_START_DATE
,REPORT_DATE
,ORDER_YEAR
,ORDER_MONTH
,START_DATE
,END_DATE
,ANNUAL_LEAVE_DAYS
,OTHER_LEAVE_DAYS
,ANNUAL_LEAVE
,OTHER_LEAVE
,PERSON_NUMBER

ORDER BY ORDER_YEAR DESC, ORDER_MONTH DESC 

-- PARAMETERS

-- DEPARTMENT
SELECT DISTINCT HAOUF.NAME,HAOUF.ORGANIZATION_ID
FROM
HR_ALL_ORGANIZATION_UNITS_F HAOU,
HR_ORGANIZATION_UNITS_F_TL HAOUF,
PER_ALL_ASSIGNMENTS_F      PAAF,
PER_ALL_PEOPLE_F           PAPF
WHERE
HAOU.ORGANIZATION_ID = HAOUF.ORGANIZATION_ID(+)
AND HAOU.ORGANIZATION_ID = PAAF.ORGANIZATION_ID (+)
AND PAAF.PERSON_ID              = PAPF.PERSON_ID (+)
AND HAOU.EFFECTIVE_START_DATE = HAOUF.EFFECTIVE_START_DATE(+)
AND HAOU.EFFECTIVE_END_DATE = HAOUF.EFFECTIVE_END_DATE(+)
AND (USERENV('LANG')) = HAOUF.LANGUAGE(+)
AND PAAF.PRIMARY_FLAG                      =  'Y'
AND PAAF.ASSIGNMENT_STATUS_TYPE            =  'ACTIVE'
AND PAAF.PRIMARY_ASSIGNMENT_FLAG           =  'Y'
AND TRUNC(SYSDATE) BETWEEN TRUNC(PAPF.EFFECTIVE_START_DATE )  AND TRUNC(PAPF.EFFECTIVE_END_DATE )
AND TRUNC(SYSDATE) BETWEEN TRUNC(PAAF.EFFECTIVE_START_DATE)  AND TRUNC(PAAF.EFFECTIVE_END_DATE)
-- AND HAOU.ATTRIBUTE2                        ='Department'
ORDER BY 1