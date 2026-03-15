# Oracle HCM Performance Document Detailed Report

## Overview

This repository contains the SQL query and supporting documentation for a **BI Publisher (BIP) report developed in Oracle HCM Cloud** to extract detailed performance document information.

The report provides a consolidated view of employee performance documents including performance document status, employee self-evaluation progress, manager evaluation progress, and employee organizational details.

This solution demonstrates the use of advanced SQL queries on the Oracle HCM Performance Management data model to support HR teams with performance monitoring and reporting.

---

## Technology Stack

* Oracle HCM Cloud
* Oracle BI Publisher (BIP)
* Oracle SQL

---

## Report Objective

The goal of this report is to provide HR teams and managers with **complete visibility into employee performance documents and evaluation workflow status**.

The report helps organizations monitor:

* Performance document progress
* Employee self-evaluation completion
* Manager evaluation completion
* Employee assignment details
* Organizational structure information

This enables HR teams to track pending evaluations and ensure timely completion of the performance review cycle.

---

## Key Data Extracted

### Employee Information

* Person Number
* Employee Name
* Assignment Number
* Assignment Status
* Person Type
* Worker Category

### Performance Document Details

* Performance Document Status
* Evaluation ID
* Evaluation Start Date
* Evaluation End Date

### Evaluation Workflow Status

* Employee Self Evaluation Status
* Manager Evaluation Status

### Organizational Information

* Business Group
* Business Unit
* Department
* Legal Employer
* Location
* Country

### Job Information

* Job Name
* Job Family
* Job Function
* Contributor Type

---

## Oracle HCM Tables Used

The SQL query retrieves information from multiple Oracle HCM modules.

### Performance Management Tables

* HRA_EVALUATIONS
* HRA_EVAL_STEPS
* HRA_EVAL_SECTIONS
* HRA_EVAL_RATINGS

These tables store performance document records, evaluation workflow steps, and rating information.

### Employee Core Data Tables

* PER_ALL_PEOPLE_F
* PER_PERSON_NAMES_F
* PER_ALL_ASSIGNMENTS_M
* PER_PERIODS_OF_SERVICE

These tables provide employee personal and assignment information.

### Organizational Data Tables

* HR_ALL_ORGANIZATION_UNITS
* HR_LOCATIONS_ALL
* PER_JOBS_F_VL
* PER_JOB_FAMILY_F_VL

These tables provide job and organizational structure information.

### Supporting Tables

* HR_LOOKUPS
* FND_LOOKUP_VALUES_VL
* FF_USER_TABLES_VL
* FF_USER_ROWS_VL

These tables are used for lookup decoding and organizational mapping.

---

## Query Logic Highlights

### Performance Document Status

The query retrieves human-readable performance document status using the lookup:

HRA_PERF_DOC_STATUS

---

### Employee Self Evaluation Status

The employee self-evaluation step is retrieved from the evaluation workflow using:

STEP_CODE = 'WSEVAL'

This identifies the status of the employee self-evaluation stage in the performance review process.

---

### Manager Evaluation Status

The manager evaluation step is retrieved using:

STEP_CODE = 'MGREVAL'

This identifies whether the manager has completed their evaluation.

---

### Organizational Mapping

The report also uses a **User Defined Table (UDT)** to derive additional organizational information such as Business Group and Business Unit mapping.

---

## Security Implementation

The report respects Oracle HCM security policies using the secured person list view:

PER_PERSON_SECURED_LIST_V

This ensures that report users can only view employees permitted by their security profile.

---

## Key Features

* Extracts detailed performance document data from Oracle HCM Cloud
* Displays evaluation workflow progress
* Tracks employee and manager evaluation completion
* Integrates employee, assignment, and organizational information
* Uses lookup decoding for readable status values
* Supports parameter-based filtering for flexible reporting
* Designed for HR and performance management monitoring

---

## Repository Structure

```
oracle-hcm-performance-document-detailed-report
│
├── README.md
└── performance_document_detailed_report.sql

```

---

## Screenshots

The screenshots folder may include:

* BI Publisher Data Model
* Report Parameter Screen
* Sample Report Output

All screenshots should mask or anonymize employee personal data.

---

## Use Cases

This report can be used by:

* HR Business Partners
* Performance Management Teams
* HR Leadership
* Managers tracking evaluation progress

---

## Learning Outcomes

Developing this report required knowledge of:

* Oracle HCM Performance Management data model
* Performance document workflow structure
* BI Publisher reporting development
* Oracle HCM security model
* SQL query optimization and lookup decoding

---

## Author

Saurabh Mharolkar
Oracle HCM Developer

---

## License

This project is licensed under the MIT License.
