# SQL Submission Guidelines and Formatting Guide
This guide lists the **requirements** for new SQL submissions and modifications. See the *modifications* section for rules on modifying prexisiting SQLs
## **Requirements**

- **Header**: Your header must contain a valid Jira Key/CR Number. If there are no CRs that apply, or the SQL is generalized to a common occurence in support, please choose a short but fitting title.

(ie. `-- Header: EVO-12345 Update Statement to Correct Taxes `)

- **SQL Description**: A brief description of your SQL and it's purpose. If applicable, include how it relates the the CR.

(ie. `-- SQL Description: This SQL is used to find the Payroll Plus Client ID of all stores in a database`)

- **Jira Key/CR Number**: If applicable, include CR Number with the link. 

(ie. `-- Jira Key/CR Number: EVO-12345 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-12345`)

- **SQL Statement**: Your SQL Statement

```
-- SQL Statement:

SELECT *
FROM papartinvoice
WHERE partinvoiceid = xxxx
```
