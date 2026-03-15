WITH
    DOC_STATUS
    AS
        (SELECT  /*+ MATERIALIZE */
                StatusLookupPEO.MEANING, StatusLookupPEO.LOOKUP_CODE
           FROM HR_LOOKUPS StatusLookupPEO
          WHERE 1 = 1 AND StatusLookupPEO.LOOKUP_TYPE = 'HRA_PERF_DOC_STATUS'),
    EMP_EV
    AS
        (SELECT  /*+ MATERIALIZE */
                PER_EXTRACT_UTILITY.GET_DECODED_LOOKUP (
                    'HRA_EVAL_STEP_STATUS',
                    HES1.STEP_STATUS)
                    Employee_SELF_EVAl_Status,
                HES1.EVALUATION_ID
           FROM HRA_EVAL_STEPS HES1
          WHERE     HES1.STEP_CODE = 'WSEVAL'
                AND HES1.SEQUENCE_NUMBER =
                    (SELECT MAX (HESE.SEQUENCE_NUMBER)
                       FROM HRA_EVAL_STEPS HESE
                      WHERE     HESE.EVAL_PARTICIPANT_ID =
                                HES1.EVAL_PARTICIPANT_ID
                            AND HESE.EVALUATION_ID = HES1.EVALUATION_ID
                            AND HESE.STEP_CODE = 'WSEVAL')),
    MGR_EV
    AS
        (SELECT  /*+ MATERIALIZE */
                PER_EXTRACT_UTILITY.GET_DECODED_LOOKUP (
                    'HRA_EVAL_STEP_STATUS',
                    HES2.STEP_STATUS)
                    MGR_EVAl_Status,
                HES2.EVALUATION_ID
           FROM HRA_EVAL_STEPS HES2
          WHERE     HES2.STEP_CODE = 'MGREVAL'
                AND HES2.SEQUENCE_NUMBER =
                    (SELECT MAX (HESE.SEQUENCE_NUMBER)
                       FROM HRA_EVAL_STEPS HESE
                      WHERE     HESE.EVAL_PARTICIPANT_ID =
                                HES2.EVAL_PARTICIPANT_ID
                            AND HESE.EVALUATION_ID = HES2.EVALUATION_ID
                            AND HESE.STEP_CODE = 'MGREVAL')),
	 Org_UDT
    AS
        (SELECT  /*+ MATERIALIZE */
                fuci_bg.VALUE business_group, fur.row_name business_unit
           FROM Fusion.ff_user_tables_vl           fut,
                Fusion.ff_user_rows_vl             fur,
                Fusion.ff_user_columns_vl          fuc_bg,
                Fusion.ff_user_column_instances_f  fuci_bg
          WHERE     1 = 1
                AND UPPER (fut.base_user_table_name) =
                    'UDT_NAME'
                AND fut.user_table_id = fur.user_table_id
                AND TRUNC (SYSDATE) BETWEEN TRUNC (fur.effective_start_date)
                                        AND TRUNC (fur.effective_end_date)
                AND fut.user_table_id = fuc_bg.user_table_id
                AND fuc_bg.user_column_name = 'Business_Group'
                AND fuc_bg.user_column_id = fuci_bg.user_column_id
                AND fur.user_row_id = fuci_bg.user_row_id
                AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                fuci_bg.effective_start_date(+))
                                        AND TRUNC (
                                                fuci_bg.effective_end_date)),
    RATINGS
    AS
        (SELECT he.EVALUATION_ID,
                osm.PERFORMANCE_RATING AS MANAGER_OS_RATING,
                osw.PERFORMANCE_RATING AS WORKER_OS_RATING,
                osm.LAST_UPDATED_BY,
                osm.LAST_UPDATE_DATE
           FROM HRA_EVALUATIONS  he,
                (SELECT hes.EVALUATION_ID,
                        hrl.RATING_DESCRIPTION PERFORMANCE_RATING,
                        her.COMMENTS           COMMENTS,
                        her.LAST_UPDATED_BY,
                        her.LAST_UPDATE_DATE
                   FROM HRA_EVAL_SECTIONS     hes,
                        HRA_EVAL_RATINGS      her,
                        HRT_RATING_LEVELS_TL  hrl
                  WHERE     1 = 1
                        AND hes.EVALUATION_ID = her.EVALUATION_ID
                        AND hes.SECTION_TYPE_CODE = 'OS'
                        AND hes.EVAL_SECTION_ID = her.REFERENCE_ID
                        AND hrl.RATING_LEVEL_ID = her.PERFORMANCE_RATING_ID
                        AND hrl.LANGUAGE = 'US'
                        AND her.ROLE_TYPE_CODE = 'MANAGER') osm,
                (SELECT hes.EVALUATION_ID,
                        hrl.RATING_DESCRIPTION PERFORMANCE_RATING,
                        her.COMMENTS           COMMENTS
                   FROM HRA_EVAL_SECTIONS     hes,
                        HRA_EVAL_RATINGS      her,
                        HRT_RATING_LEVELS_TL  hrl
                  WHERE     1 = 1
                        AND hes.EVALUATION_ID = her.EVALUATION_ID
                        AND hes.SECTION_TYPE_CODE = 'OS'
                        AND hes.EVAL_SECTION_ID = her.REFERENCE_ID
                        AND hrl.RATING_LEVEL_ID = her.PERFORMANCE_RATING_ID
                        AND hrl.LANGUAGE = 'US'
                        AND her.ROLE_TYPE_CODE = 'WORKER') osw
          WHERE     1 = 1
                AND he.EVALUATION_ID = osm.EVALUATION_ID(+)
                AND he.EVALUATION_ID = osw.EVALUATION_ID(+)
                AND (   osm.PERFORMANCE_RATING IN (:P_MANAGER_OS_RATING)
                     OR (LEAST (:P_MANAGER_OS_RATING) IS NULL))),
	World_Areas
    AS
        (SELECT fuci_plat.VALUE world_area, fur.row_name Country
           FROM ff_user_tables_vl           fut,
                ff_user_rows_vl             fur,
                ff_user_columns_vl          fuc_plat,
                ff_user_column_instances_f  fuci_plat
          WHERE     1 = 1
                AND UPPER (fut.base_user_table_name) = 'EMR_WORLD_AREAS'
                AND fut.user_table_id = fur.user_table_id
                AND TRUNC (SYSDATE) BETWEEN fur.effective_start_date 
                                AND fur.effective_end_date
                AND fut.user_table_id = fuc_plat.user_table_id
                AND fuc_plat.user_column_name = 'World_Area'
                AND fuc_plat.user_column_id = fuci_plat.user_column_id
                AND fur.user_row_id = fuci_plat.user_row_id(+)
                AND TRUNC (SYSDATE) BETWEEN fuci_plat.effective_start_date(+)
                                AND fuci_plat.effective_end_date(+)),

MGR_LEVEL
    AS
        (SELECT full_name,
                person_id empId,
               -- manager_level,
               -- MANAGER_TYPE,
                manager_id
           FROM (SELECT mgr_ppnf.full_name,
                        man.person_id,
                        --'Functional Reports To' manager_level,
                        --man.MANAGER_TYPE,
                        man.manager_id
                   FROM FUSION.per_manager_hrchy_dn  man,
                        FUSION.per_all_people_f      papf,
                        FUSION.per_person_names_f    mgr_ppnf
                  WHERE     man.person_id = mgr_ppnf.person_id
                        AND mgr_ppnf.name_type = 'GLOBAL'
                        AND man.MANAGER_ID = papf.person_id
                        AND man.MANAGER_TYPE = 'FUNC_REPORT'
                        AND man.manager_level <= 1
                        AND 'Y' = :p_functional_reports_to         -- Y/N flag
                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                        mgr_ppnf.effective_start_date)
                                                AND TRUNC (
                                                        mgr_ppnf.effective_end_date)
                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                        papf.effective_start_date)
                                                AND TRUNC (
                                                        papf.effective_end_date)
                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                        man.effective_start_date)
                                                AND TRUNC (
                                                        man.effective_end_date)
                        AND NOT EXISTS
                                (SELECT man2.person_id
                                   FROM FUSION.per_manager_hrchy_dn man2
                                  WHERE     1 = 1
                                        AND man2.MANAGER_TYPE =
                                            'LINE_MANAGER'
                                        AND man2.person_id = man.person_id
                                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                        man2.effective_start_date)
                                                                AND TRUNC (
                                                                        man2.effective_end_date)
                                                         AND (   man2.manager_id IN (:MANAGER_NAME)
                                                          OR (LEAST (:MANAGER_NAME) IS NULL))
                                                         AND (   man2.manager_id IN (:P_LINE_MGR_ID)
                                                                   OR (LEAST (:P_LINE_MGR_ID) IS NULL))      )
                 UNION
                 SELECT mgr_ppnf.full_name,
                        man.person_id,
                        man.manager_id
                   FROM FUSION.per_manager_hrchy_dn  man,
                        FUSION.per_all_people_f      papf,
                        FUSION.per_person_names_f    mgr_ppnf
                  WHERE     man.person_id = mgr_ppnf.person_id
                        AND mgr_ppnf.name_type = 'GLOBAL'
                        AND man.MANAGER_ID = papf.person_id
                        AND man.MANAGER_TYPE = 'LINE_MANAGER'
                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                        mgr_ppnf.effective_start_date)
                                                AND TRUNC (
                                                        mgr_ppnf.effective_end_date)
                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                        papf.effective_start_date)
                                                AND TRUNC (
                                                        papf.effective_end_date)
                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                        man.effective_start_date)
                                                AND TRUNC (
                                                        man.effective_end_date)
                 UNION
                 SELECT mgr_ppnf.full_name,
                        papf.person_id,
                        papf.person_id manager_id
                   FROM FUSION.per_all_people_f    papf,
                        FUSION.per_person_names_f  mgr_ppnf
                  WHERE     papf.person_id = mgr_ppnf.person_id
                        AND mgr_ppnf.name_type = 'GLOBAL'
                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                        mgr_ppnf.effective_start_date)
                                                AND TRUNC (
                                                        mgr_ppnf.effective_end_date)
                        AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                        papf.effective_start_date)
                                                AND TRUNC (
                                                        papf.effective_end_date))
          WHERE 1=1
           AND (  manager_id IN (:MANAGER_NAME)
              OR (LEAST (:MANAGER_NAME) IS NULL))
         AND (   manager_id IN (:P_LINE_MGR_ID)
              OR (LEAST (:P_LINE_MGR_ID) IS NULL))),
	FUNC_REPORTS_TO_Data
    AS
        (SELECT pasf.manager_assignment_id func_reports_to_asg_id,
                pasf.manager_id,
                pn.full_name               func_reports_to_name,
                paam_mgr.assignment_number func_reports_to_asg_number,
                papfs.person_number        func_reports_to_number,
                pasf.assignment_id,
				past.user_status              assignment_status_fn
           FROM per_assignment_supervisors_f  pasf,
                per_person_names_f            pn,
                per_all_people_f              papfs,
                per_all_assignments_m         paam_mgr,
				per_assignment_status_types_vl  past
          WHERE     1 = 1                 
                AND pn.name_type = 'GLOBAL'
                AND TRUNC (SYSDATE) BETWEEN pn.effective_start_date AND pn.effective_end_date
                AND pn.person_id = pasf.manager_id
                AND papfs.person_id = pasf.manager_id
                AND TRUNC (SYSDATE) BETWEEN papfs.effective_start_date AND papfs.effective_end_date
                AND paam_mgr.person_id = pasf.manager_id
                AND paam_mgr.assignment_id = pasf.manager_assignment_id
                AND TRUNC (SYSDATE) BETWEEN paam_mgr.effective_start_date AND paam_mgr.effective_end_date
                AND TRUNC (SYSDATE) BETWEEN pasf.effective_start_date AND pasf.effective_end_date
                AND paam_mgr.effective_latest_change = 'Y'
                AND pasf.manager_type = 'FUNC_REPORT'
				AND paam_mgr.assignment_Status_type_id = past.assignment_Status_type_id
				),
    REPORTS_TO_data
    AS
        (SELECT pasf.manager_assignment_id reports_to_asg_id,
                pasf.manager_id,
                pn.full_name               reports_to_name,
                paam_mgr.assignment_number reports_to_asg_number,
                papfs.person_number        reports_to_number,
                pasf.assignment_id,
				past.user_status              assignment_status_ln
           FROM per_assignment_supervisors_f  pasf,
                per_person_names_f            pn,
                per_all_people_f              papfs,
                per_all_assignments_m         paam_mgr,
				per_assignment_status_types_vl  past
          WHERE     1 = 1                 
                AND pn.name_type = 'GLOBAL'
                AND TRUNC (SYSDATE) BETWEEN pn.effective_start_date AND pn.effective_end_date
                AND pn.person_id = pasf.manager_id
                AND papfs.person_id = pasf.manager_id
                AND TRUNC (SYSDATE) BETWEEN papfs.effective_start_date AND papfs.effective_end_date
                AND paam_mgr.person_id = pasf.manager_id
                AND paam_mgr.assignment_id = pasf.MANAGER_ASSIGNMENT_ID
                AND TRUNC (SYSDATE) BETWEEN paam_mgr.effective_start_date AND paam_mgr.effective_end_date
                AND TRUNC (SYSDATE) BETWEEN pasf.effective_start_date AND pasf.effective_end_date
				AND paam_mgr.effective_latest_change = 'Y'
                AND pasf.MANAGER_TYPE = 'LINE_MANAGER'
				AND paam_mgr.assignment_Status_type_id = past.assignment_Status_type_id
				)
SELECT DISTINCT
         papf.person_number Emp_Id,
         pam.assignment_number,
         ppnf.last_name || ', ' || ppnf.first_name name,
         peaw.email_address Work_Email,
         HE.EVALUATION_ID eval_id,
         TO_NCHAR (HE.LAST_UPDATE_DATE,
                   'DD-Mon-YYYY',
                   'NLS_DATE_LANGUAGE=AMERICAN')
             LAST_UPDATE_Date,
         HE.LAST_UPDATED_BY,
		  HTPT.CUSTOMARY_NAME
             Doc_Name,
         DOC_STATUS.MEANING
             DOCUMENT_STATUS,
         (SELECT COUNT (*)
            FROM HRG_GOALS               HGC,
                 HRG_GOAL_PLAN_GOALS     HGPGC,
                 HRG_GOAL_PLANS_VL       HGPL,
                 hrg_goal_pln_assignments gpa
           WHERE     HGC.PERSON_ID = gpa.PERSON_ID
                 AND HGC.GOAL_ID = HGPGC.GOAL_ID
                 AND HGPGC.GOAL_PLAN_ID = HGPL.GOAL_PLAN_ID
                 AND HGC.GOAL_VERSION_TYPE_CODE = 'ACTIVE'
                 AND HGC.STATUS_CODE NOT IN ('DELETED', 'CANCEL')
                 AND gpa.GOAL_PLAN_ID = HGPL.GOAL_PLAN_ID
                 AND gpa.REVIEW_PERIOD_ID = HRPL.REVIEW_PERIOD_ID
                 AND pam.assignment_id = gpa.assignment_id)
             Goals_Count,
         TO_NCHAR (HE.START_DATE, 'DD-Mon-YYYY', 'NLS_DATE_LANGUAGE=AMERICAN')
             Doc_Start_Date,
         TO_NCHAR (HE.END_DATE, 'DD-Mon-YYYY', 'NLS_DATE_LANGUAGE=AMERICAN')
             Doc_End_Date,
		 EMP_EV.Employee_SELF_EVAl_Status,
         MGR_EV.MGR_EVAl_Status,
		 Org_UDT.business_group,
         haoufvl_bu.name
             BU_UNIT,
         HAOU.NAME
             EMPLOYEE_DEPARTMENT,
         LE.NAME
             EMPLOYEE_LEGAL_EMPLOYER,
		 RAT.MANAGER_OS_RATING,
         DECODE (EMP_EV.Employee_SELF_EVAl_Status,
                 'Completed', RAT.WORKER_OS_RATING,
                 NULL)
             WORKER_OS_RATING,
		 HRPL.REVIEW_PERIOD_NAME,
		  World_Areas.world_area
             WORLD_AREA,
         hg.geography_name
             AS LEGAL_EMPLOYER_COUNTRY,
         job.name
             job_name,
         job_family.job_family_name
             job_family,
         per_extract_utility.get_decoded_lookup ('JOB_FUNCTION_CODE',
                                                 job.job_function_code)
             job_function,
         job.attribute12
             job_function_group,
         job.manager_level
             contributor_type,
         job.attribute13
             contributor_type_level,
         job.APPROVAL_AUTHORITY
             ORG_LEVEL,
         pam.assignment_name,
         PASTT.USER_STATUS
             Assignment_status,
         DECODE (pam.PRIMARY_FLAG,  'Y', 'Yes',  'N', 'No')
             Primary_assignment,
         DECODE (pam.EMPLOYMENT_CATEGORY,
                 'FT', 'Full-time temporary',
                 'PR', 'Part-time regular',
                 'FR', 'Full-time regular',
                 'PT', 'Part-time temporary',
                 pam.FREQUENCY, pam.EMPLOYMENT_CATEGORY)
             Assignment_Category,
         ppt.user_person_type
             person_type,
         FLV.MEANING
             worker_category,
         DECODE (pam.HOURLY_SALARIED_CODE,  'S', 'Salaried',  'H', 'Hourly')
             Hourly_or_Salaried,
         TO_CHAR (ppos.actual_termination_date,
                  'dd-Mon-YYYY',
                  'NLS_DATE_LANGUAGE=AMERICAN')
             Termination_date,
         TO_CHAR (ppos.date_start, 'dd-Mon-YYYY', 'NLS_DATE_LANGUAGE=AMERICAN')
             LE_Start_Date,
         TO_CHAR (ppos.adjusted_svc_date,
                  'DD-Mon-YYYY',
                  'NLS_DATE_LANGUAGE = AMERICAN')
             latest_start_date,
		 FUNC_REPORTS_TO.Assignment_status_fn,
		 FUNC_REPORTS_TO.FUNC_REPORTS_TO_name FUNC_MGR_NAME,
		 FUNC_REPORTS_TO.FUNC_REPORTS_TO_number FUNC_MGR_ID,
		 FUNC_REPORTS_TO.FUNC_REPORTS_TO_asg_number,
		 FUNC_REPORTS_TO.FUNC_REPORTS_TO_ASG_ID,	 
         REPORTS_TO.REPORTS_TO_name FULL_NAME, 
         REPORTS_TO.REPORTS_TO_number LINE_MGR_ID,
         REPORTS_TO.REPORTS_TO_asg_number,
         REPORTS_TO.REPORTS_TO_asg_id,
		 REPORTS_TO.Assignment_status_ln,
		 (SELECT (PEAW_FUN_MANAGER.email_address)
            FROM per_email_addresses         PEAW_FUN_MANAGER,
                 per_assignment_supervisors_f pasf
           WHERE     pasf.assignment_id = pam.assignment_id
                 AND pasf.manager_type = 'FUNC_REPORT'
                 --and pasf.primary_flag = 'Y'
                 AND PASF.MANAGER_ID = PEAW_FUN_MANAGER.person_id(+)
				 AND TRUNC (SYSDATE) BETWEEN pasf.effective_start_date
                                               AND pasf.effective_end_date
                 AND PEAW_FUN_MANAGER.email_type(+) = 'W1'
                 AND TRUNC (SYSDATE) BETWEEN PEAW_FUN_MANAGER.DATE_FROM(+)
                                 AND COALESCE (
                                         PEAW_FUN_MANAGER.DATE_TO(+),
                                         TO_DATE ('4712/12/31', 'YYYY/MM/DD'))
                 AND ROWNUM = 1)
             FUNC_MGR_EMAIL,
		 (SELECT (PEAW_LN_MANAGER.email_address)
            FROM per_email_addresses         PEAW_LN_MANAGER,
                 per_assignment_supervisors_f pasf
           WHERE     pasf.assignment_id = pam.assignment_id
                 AND pasf.manager_type = 'LINE_MANAGER'
                 --and pasf.primary_flag = 'Y'
                 AND PASF.MANAGER_ID = PEAW_LN_MANAGER.person_id(+)
				 AND TRUNC (SYSDATE) BETWEEN pasf.effective_start_date
                                               AND pasf.effective_end_date
                 AND PEAW_LN_MANAGER.email_type(+) = 'W1'
                 AND TRUNC (SYSDATE) BETWEEN PEAW_LN_MANAGER.DATE_FROM(+)
                                 AND COALESCE (
                                         PEAW_LN_MANAGER.DATE_TO(+),
                                         TO_DATE ('4712/12/31', 'YYYY/MM/DD'))
                 AND ROWNUM = 1)
             Reports_to_MNGR_Work_Email
         
 FROM 
		 per_all_people_f              papf,
		 per_all_assignments_m         pam,
         PER_PERIODS_OF_SERVICE        PPOS,
         per_person_names_f            ppnf,
         per_email_addresses           peaw,
         HRA_EVALUATIONS               he,
		 HRA_TMPL_PERIODS_VL           HTPT,
         HRT_REVIEW_PERIODS_TL         HRPL,
		 DOC_STATUS,
         EMP_EV,
         MGR_EV,
		 Org_UDT,
         hr_all_organization_units_f_vl haoufvl_bu,
         HR_ALL_ORGANIZATION_UNITS     HAOU,
         HR_ALL_ORGANIZATION_UNITS     LE,
		 RATINGS                       RAT,
		 per_jobs_f_vl                 job,
         per_job_family_f_vl           job_family,
         PER_ASSIGNMENT_STATUS_TYPES_TL PASTT,
         per_person_types_vl           ppt,
         fnd_lookup_values_vl          FLV,
		 World_Areas,
         hz_geographies                hg,
		 FUNC_REPORTS_TO_Data FUNC_REPORTS_TO,		
		 REPORTS_TO_data  REPORTS_TO
		 
WHERE     1 = 1
         AND TRUNC (SYSDATE) BETWEEN papf.effective_start_Date
                         AND papf.effective_end_Date
         AND pam.effective_latest_change = 'Y'
         AND papf.person_id = pam.person_id
         AND PAM.ASSIGNMENT_TYPE IN ('E', 'C')
         AND PAM.PERIOD_OF_SERVICE_ID = PPOS.PERIOD_OF_SERVICE_ID
         AND TRUNC (SYSDATE) BETWEEN pam.effective_start_Date
                         AND pam.effective_end_Date 
         AND ppnf.person_id = papf.person_id
         AND ppnf.name_type = 'GLOBAL'
         AND TRUNC (SYSDATE) BETWEEN ppnf.effective_start_Date
                         AND ppnf.effective_end_Date
         AND papf.person_id = peaw.person_id(+)
         AND papf.person_id IN (SELECT empId FROM MGR_LEVEL)
         AND peaw.email_type(+) = 'W1'
         AND TRUNC (SYSDATE) BETWEEN peaw.DATE_FROM(+)
                                 AND COALESCE (
                                         peaw.DATE_TO(+),
                                         TO_DATE ('4712/12/31', 'YYYY/MM/DD'))
         AND pam.assignment_id = HE.assignment_id
         AND HTPT.TMPL_PERIOD_ID = HE.TMPL_PERIOD_ID
         AND HTPT.REVIEW_PERIOD_ID = HRPL.REVIEW_PERIOD_ID
         AND HRPL.LANGUAGE = 'US'
		 AND DOC_STATUS.LOOKUP_CODE = HE.STATUS_CODE
		 AND EMP_EV.EVALUATION_ID(+) = HE.EVALUATION_ID
         AND MGR_EV.EVALUATION_ID(+) = HE.EVALUATION_ID
		 AND HE.EVALUATION_ID = RAT.EVALUATION_ID
		 AND pam.business_unit_id = haoufvl_bu.organization_id
         AND TRUNC (SYSDATE) BETWEEN haoufvl_bu.effective_start_date
                                 AND haoufvl_bu.effective_end_date
         AND UPPER (haoufvl_bu.name) = UPPER (Org_UDT.business_unit(+))
		 AND PAM.ORGANIZATION_ID = HAOU.ORGANIZATION_ID(+)
         AND TRUNC (SYSDATE) BETWEEN TRUNC (HAOU.EFFECTIVE_START_DATE(+))
                                 AND TRUNC (HAOU.EFFECTIVE_END_DATE(+))
         AND PAM.LEGAL_ENTITY_ID = LE.ORGANIZATION_ID
         AND TRUNC (SYSDATE) BETWEEN TRUNC (LE.EFFECTIVE_START_DATE)
                                 AND TRUNC (LE.EFFECTIVE_END_DATE)
		 and pam.assignment_id =FUNC_REPORTS_TO.assignment_id (+)
         and pam.assignment_id = REPORTS_TO.assignment_id (+)
		 AND pam.job_id = job.job_id(+)
         AND job.job_family_id = job_family.job_family_id(+)
         AND TRUNC (SYSDATE) BETWEEN job.effective_start_date(+)
                                 AND job.effective_end_date(+)
         AND TRUNC (SYSDATE) BETWEEN job_family.effective_start_date(+)
                                 AND job_family.effective_end_date(+)
         AND PAM.ASSIGNMENT_STATUS_TYPE_ID = PASTT.ASSIGNMENT_STATUS_TYPE_ID(+)
         AND PASTT.LANGUAGE = 'US'
         AND pam.person_type_id = ppt.person_type_id
         AND FLV.lookup_code = pam.EMPLOYEE_CATEGORY
         AND FLV.lookup_type = 'EMPLOYEE_CATG'
		 AND hg.geography_type = 'COUNTRY'
         AND hg.geography_code = pam.legislation_code
         AND World_Areas.Country(+) = hg.geography_name
         AND PAPF.PERSON_ID NOT IN
                 (SELECT DISTINCT pu.person_id
                    FROM FND_SESSIONS   FS,
                         PER_USERS      PU,
                         PER_USER_ROLES PUR,
                         PER_ROLES_DN_TL PRD
                   WHERE     1 = 1
                         AND FS.SESSION_ID = FND_GLOBAL.SESSION_ID
                         AND FS.USER_GUID = PU.USER_GUID
                         AND PU.ACTIVE_FLAG = 'Y'
                         AND PU.END_DATE IS NULL)
		 AND papf.person_id IN (SELECT DISTINCT person_id FROM per_person_secured_list_v)
		 --Parameters
		  AND (   Papf.PERSON_ID IN (:PERSON_NUMBER)
              OR (LEAST (:PERSON_NUMBER) IS NULL))
          AND (   ppnf.PERSON_ID IN (:PERSON_NAME)
              OR (LEAST (:PERSON_NAME) IS NULL))
		  AND (HTPT.CUSTOMARY_NAME IN (:DOC_NAME) OR LEAST (:DOC_NAME) IS NULL)
		  AND (   DOC_STATUS.MEANING IN (:P_DOCUMENT_STATUS)
              OR (LEAST (:P_DOCUMENT_STATUS) IS NULL))
		  AND (   EMP_EV.Employee_SELF_EVAl_Status IN (:P_SELF_EVAL_STATUS)
              OR (LEAST (:P_SELF_EVAL_STATUS) IS NULL))
          AND (   MGR_EV.MGR_EVAL_STATUS IN (:P_MGR_EVAL_STATUS)
              OR (LEAST (:P_MGR_EVAL_STATUS) IS NULL))
          AND (   Org_UDT.business_group IN (:BusinessGroup)
              OR (LEAST (:BusinessGroup) IS NULL))
          AND (haoufvl_bu.name IN (:P_BU_NAME) OR (LEAST (:P_BU_NAME) IS NULL))
          AND (HAOU.NAME IN (:P_DEP_NAME) OR (LEAST (:P_DEP_NAME) IS NULL))
          AND (   PAM.legislation_code IN (:P_LE_COUNTRY)
              OR (LEAST (:P_LE_COUNTRY) IS NULL))
          AND (pam.location_id IN (:Location) OR (LEAST (:Location) IS NULL))
		   AND (   PASTT.USER_STATUS IN (:ASSIGNMENT_STATUS)
              OR (LEAST (:ASSIGNMENT_STATUS) IS NULL))
         AND (   ppt.user_person_type IN (:P_PERSON_TYPE)
              OR (LEAST (:P_PERSON_TYPE) IS NULL))
         AND (   FLV.MEANING IN (:P_WORKER_CATEGORY)
              OR (LEAST (:P_WORKER_CATEGORY) IS NULL))
         AND (   :P_HOURLY_SALARIED IS NULL
              OR DECODE (pam.HOURLY_SALARIED_CODE,
                         'S', 'Salaried',
                         'H', 'Hourly') =
                 :P_HOURLY_SALARIED)
		 AND (   World_Areas.world_area IN (:P_WORLD_AREA)
              OR (LEAST (:P_WORLD_AREA) IS NULL))
         AND (LE.NAME IN (:P_LE_NAME) OR (LEAST (:P_LE_NAME) IS NULL))

ORDER BY NAME