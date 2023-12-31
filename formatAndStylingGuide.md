# SQL Submission Guidelines and Formatting Guide
This guide lists the **requirements** for new SQL submissions and modifications.  See the *modifications* section for rules on modifying prexisiting SQLs
## **Requirements**

- **Header**: Your header must contain a valid Jira Key/CR Number. If there are no CRs that apply, or the SQL is generalized to a common occurence in support, please choose a short but fitting title.

  ```sql
  -- EVO-12345 Update Statement to Correct Taxes
  --
  ```

- **SQL Description**: A brief description of your SQL and it's purpose. If applicable, include how it relates the the CR.

  ```sql
  -- SQL Description: This SQL is used to find the Payroll Plus Client ID of all stores in a database
  ```

- ### Comment block before SQL to explain how to use

  ```sql
  -- How to Use: Remove the xxxxx with and replace with a valid sales deal number.
  ```

- **Jira Key/CR Number**: If applicable, include CR Number with the link. 

  ```sql
  -- Jira Key/CR Number: EVO-12345 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-12345
  ```

- **SQL Statement**: Your SQL Statement

  ```sql
  -- SQL Statement:

  SELECT *
  FROM papartinvoice
  WHERE partinvoiceid = xxxx
  ```

### Completed SQL Statement:
  It should look similar to this, however this is the bare minimum required. Please include as many optional items as possible.

  ```sql
  -- EVO-12345 Update Statement to Correct Taxes
  --
  -- SQL Description: This SQL is used to find the Payroll Plus Client ID of all stores in a database
  -- How to Use: Copy the SQL statement, paste it in phoenix, and click run, no modification is neccesary.
  -- Jira Key/CR Number: EVO-12345 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-12345
  -- SQL Statement:

  SELECT *
  FROM papartinvoice pi
  LEFT JOIN papartinvoiceline pil ON pil.partinvoiceid = pi.partinvoiceid
  WHERE pil.partinvoiceid IS NULL
    AND pil.dtstamp < '12/12/1212';
  ```
<br>

## **Optional**
  *although optional, they are strongly encouraged to include in your SQLs*

  - ##### Comment block explaining SQL:
    To explain how it works (*You can place this anywhere in your query but some placing it near the top is what I would advise*)
    The more descriptive you are the better. If you are simply explaining how the SQL corrects an error, or obtains the information,
    any information is better than none.

    ```sql
    /* This SQL uses two joins on cocategory. One of these is an INNER JOIN on the parts categoryid,
    to grab the relevant sales category information. The other join, is a LEFT JOIN used to find a
    replacement sales category. If it does not exists, that column will output blank. The where filter at the
    bottom (WHERE replacementcat.storeid = p.stored) is used to filter out the results from the LEFT JOIN,
    where the category storeid matches that of the parts storeid. */
    ```

  - #### Comments Explaining Joins and Filters:

    ```sql
    SELECT pil.partinvoicelineid AS partinvline, pil.partinvoiceid AS partinvid -- Adds an aliias to the column
    FROM papartinvoice pi -- part invoice table
    LEFT JOIN papartinvoiceline pil ON pil.partinvoiceid = pi.partinvoiceid -- join to include part invoice line information where it's relevant
    WHERE pi.partinvoicenumber IN (123, 456, 789) -- filter for 3 specific part invoice numbers
      AND pil.dtstamp < '12/12/1212'; -- where date is less than 12/12/1212
    ORDER BY pi.partinvoiceid -- order output to group lines by part invoice id
    ```

<br>

## **Completed SQL Statement**

  ```sql
  -- EVO-12345 Update Statement to Correct Taxes
  --
  -- SQL Description: This SQL is used to find the Payroll Plus Client ID of all stores in a database
  -- How to Use: Copy the SQL statement, paste it in phoenix, and click run, no modification is neccesary.
  -- Jira Key/CR Number: EVO-12345 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-12345
  -- SQL Statement:

  /* This SQL uses two joins on cocategory. One of these is an INNER JOIN on the parts categoryid,
  to grab the relevant sales category information. The other join, is a LEFT JOIN used to find a
  replacement sales category. If it does not exists, that column will output blank. The where filter at the
  bottom (WHERE replacementcat.storeid = p.stored) is used to filter out the results from the LEFT JOIN,
  where the category storeid matches that of the parts storeid. */

  SELECT pil.partinvoicelineid AS partinvline, pil.partinvoiceid AS partinvid -- Adds an aliias to the column
  FROM papartinvoice pi -- part invoice table
  LEFT JOIN papartinvoiceline pil ON pil.partinvoiceid = pi.partinvoiceid -- join to include part invoice line information where it's relevant
  WHERE pi.partinvoicenumber IN (123, 456, 789) -- filter for 3 specific part invoice numbers
  AND pil.dtstamp < '12/12/1212'; -- where date is less than 12/12/1212
  ORDER BY pi.partinvoiceid; -- order output to group lines by part invoice id
  ```

## **Modifications**

If you aim to append a pre-existing SQL, please make a new branch and make your changes. For a guide on how to do that, please read our guide on [appending previously submitted sqls]()

### **Required Items for Approval**

- **Changelog**:
  if you are making changes to a previously submitted SQL, you must leave a note with formatting like this

  ```sql
  -- Changelog:
  /* Modified By Trevor L 8/25/2023: Removed nested query and turned it into a left join to speed up the SQL run time. */
  ```

  if you dont see any of the required items listed in the submission portion of this document, on the SQL you are modifying, please add them.

- **Comments Hightlighting Your Changes**

  example:
  ```LEFT JOIN table1 tab1 ON tab1.id = tab2.id -- Modified by Trevor L 8/25/2023```

  If adding the comments makes the statement look busy or undermines / replaces previous comments used to explain, you can exclude them from your
  submission however it is strongly encouraged.

<br>

## **Completed SQL Statement**

  ```sql
  -- EVO-12345 Select Statement to Identify Part Invoice
  --
  -- SQL Description: This SQL is used to find the Payroll Plus Client ID of all stores in a database
  -- How to Use: Copy the SQL statement, paste it in phoenix, and click run, no modification is neccesary.
  -- Jira Key/CR Number: EVO-12345 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-12345
  -- SQL Statement:

  /* This SQL uses two joins on cocategory. One of these is an INNER JOIN on the parts categoryid,
  to grab the relevant sales category information. The other join, is a LEFT JOIN used to find a
  replacement sales category. */

  SELECT pil.partinvoicelineid AS partinvline, pil.partinvoiceid AS partinvid -- Adds an aliias to the column
  FROM papartinvoice pi -- part invoice table
  LEFT JOIN papartinvoiceline pil ON pil.partinvoiceid = pi.partinvoiceid -- join to include part invoice line information where it's relevant
  WHERE pi.partinvoicenumber IN (123, 456, 789) -- filter for 3 specific part invoice numbers

  -- Changelog:
  /* Modified by John Doe 8/25/23: added comments at the end of clauses for documentation */
  ```

### *If you ever have any questions about formatting please pm me @Trevor Lichfield on slack* ###
