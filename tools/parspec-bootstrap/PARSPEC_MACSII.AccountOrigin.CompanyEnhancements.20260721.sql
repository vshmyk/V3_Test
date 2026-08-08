USE [PARSPEC_MACSII];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('SRC.Account', 'EMAIL') IS NULL
    ALTER TABLE SRC.Account ADD EMAIL VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'BILLNAME') IS NULL
    ALTER TABLE SRC.Account ADD BILLNAME VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'BILLLINE1') IS NULL
    ALTER TABLE SRC.Account ADD BILLLINE1 VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'BILLLINE2') IS NULL
    ALTER TABLE SRC.Account ADD BILLLINE2 VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'BILLCITY') IS NULL
    ALTER TABLE SRC.Account ADD BILLCITY VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'BILLSTATE') IS NULL
    ALTER TABLE SRC.Account ADD BILLSTATE VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'BILLZIP') IS NULL
    ALTER TABLE SRC.Account ADD BILLZIP VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'BILLCOUNTY') IS NULL
    ALTER TABLE SRC.Account ADD BILLCOUNTY VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'BILLCOUNTRY') IS NULL
    ALTER TABLE SRC.Account ADD BILLCOUNTRY VARCHAR(255) NULL;
GO
IF COL_LENGTH('SRC.Account', 'ORDERENTRYNOTES') IS NULL
    ALTER TABLE SRC.Account ADD ORDERENTRYNOTES VARCHAR(4000) NULL;
GO
IF COL_LENGTH('SRC.Account', 'INTERNALNOTES') IS NULL
    ALTER TABLE SRC.Account ADD INTERNALNOTES VARCHAR(4000) NULL;
GO
IF COL_LENGTH('SRC.Account', 'TERMTEXT') IS NULL
    ALTER TABLE SRC.Account ADD TERMTEXT VARCHAR(4000) NULL;
GO
IF COL_LENGTH('SRC.Account', 'INVOICETERMTEXT') IS NULL
    ALTER TABLE SRC.Account ADD INVOICETERMTEXT VARCHAR(4000) NULL;
GO
IF COL_LENGTH('SRC.Account', 'TAXID') IS NULL
    ALTER TABLE SRC.Account ADD TAXID VARCHAR(255) NULL;
GO

ALTER PROCEDURE [SRC].[Account_Origin]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          CAST(REPLACE(DISTRIBUTORID, '''', '') AS VARCHAR(30)) AS AccountId,
          CAST(REPLACE(DISPLAYID, '''', '') AS VARCHAR(30)) AS DISPLAYID,
          UPDATEDATE,
          DISTRIBUTORNAME,
          ACTIVE,
          ROLE,
          ISNULL(CUSTOMERRANK, -1) AS CUSTOMERRANK,
          SALESUSERID,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(REPLACE(SOLDNAME, CHAR(9), ' '), CHAR(10), ' '))), '') AS VARCHAR(255)) AS SOLDNAME,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(srcAccount.SOLDLINE1, CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' '), '  ', ' '))), '') AS VARCHAR(255)) AS SOLDLINE1,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SOLDLINE2, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SOLDLINE2,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SOLDCITY, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SOLDCITY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SOLDSTATE, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SOLDSTATE,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SOLDZIP, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SOLDZIP,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(IIF(ISNULL(srcAccount.SOLDCOUNTY, '') = '', AO.Account.Cst_Sold_To_County__c, srcAccount.SOLDCOUNTY), CHAR(9), ' '))), '') AS VARCHAR(255)) AS SOLDCOUNTY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(IIF(ISNULL(srcAccount.SOLDCOUNTRY, '') = '', AO.Account.BillingCountry, srcAccount.SOLDCOUNTRY), CHAR(9), ' '))), '') AS VARCHAR(255)) AS SOLDCOUNTRY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SHIPNAME, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SHIPNAME,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SHIPLINE1, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SHIPLINE1,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SHIPLINE2, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SHIPLINE2,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SHIPCITY, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SHIPCITY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SHIPSTATE, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SHIPSTATE,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.SHIPZIP, CHAR(9), ' '))), '') AS VARCHAR(255)) AS SHIPZIP,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(IIF(ISNULL(srcAccount.SHIPCOUNTY, '') = '', AO.Account.Cst_Ship_To_County__c, srcAccount.SHIPCOUNTY), CHAR(9), ' '))), '') AS VARCHAR(255)) AS SHIPCOUNTY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(IIF(ISNULL(srcAccount.SHIPCOUNTRY, '') = '', AO.Account.ShippingCountry, srcAccount.SHIPCOUNTRY), CHAR(9), ' '))), '') AS VARCHAR(255)) AS SHIPCOUNTRY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.PHONE, CHAR(9), ' '))), '') AS VARCHAR(255)) AS PHONE,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.WEB, CHAR(9), ' '))), '') AS VARCHAR(255)) AS WEB,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.FAX, CHAR(9), ' '))), '') AS VARCHAR(255)) AS FAX,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.EMAIL, CHAR(9), ' '))), '') AS VARCHAR(255)) AS EMAIL,
          srcAccount.PARENTNAME,
          IIF(ISNULL(srcAccount.PARENTID, '') = '' AND ISNULL(AO.Account.ParentId, '') <> '', NULL, srcAccount.PARENTID) AS PARENTID,
          srcAccount.ACCOUNTTYPE,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.BILLNAME, CHAR(9), ' '))), '') AS VARCHAR(255)) AS BILLNAME,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.BILLLINE1, CHAR(9), ' '))), '') AS VARCHAR(255)) AS BILLLINE1,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.BILLLINE2, CHAR(9), ' '))), '') AS VARCHAR(255)) AS BILLLINE2,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.BILLCITY, CHAR(9), ' '))), '') AS VARCHAR(255)) AS BILLCITY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.BILLSTATE, CHAR(9), ' '))), '') AS VARCHAR(255)) AS BILLSTATE,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.BILLZIP, CHAR(9), ' '))), '') AS VARCHAR(255)) AS BILLZIP,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.BILLCOUNTY, CHAR(9), ' '))), '') AS VARCHAR(255)) AS BILLCOUNTY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.BILLCOUNTRY, CHAR(9), ' '))), '') AS VARCHAR(255)) AS BILLCOUNTRY,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(srcAccount.ORDERENTRYNOTES, CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' '))), '') AS VARCHAR(4000)) AS ORDERENTRYNOTES,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(srcAccount.INTERNALNOTES, CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' '))), '') AS VARCHAR(4000)) AS INTERNALNOTES,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(srcAccount.TERMTEXT, CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' '))), '') AS VARCHAR(4000)) AS TERMTEXT,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(srcAccount.INVOICETERMTEXT, CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' '))), '') AS VARCHAR(4000)) AS INVOICETERMTEXT,
          CAST(ISNULL(LTRIM(RTRIM(REPLACE(srcAccount.TAXID, CHAR(9), ' '))), '') AS VARCHAR(255)) AS TAXID,
          'OASIS' AS [SOURCE]
    FROM
    (
        SELECT
            Distr.DISTRIBUTORID,
            DISPLAYID,
            UPDATEDATE,
            DISTRIBUTORNAME,
            IIF(ACTIVE = 'Y', 'Active', 'Parent') AS ACTIVE,
            ROLE,
            CUSTOMERRANK,
            dbo.GetActiveUserId(IIF(SALESUSERID = '', '*', SALESUSERID)) AS SALESUSERID,
            SOLDNAME,
            SOLDLINE1,
            SOLDLINE2,
            SOLDCITY,
            SOLDSTATE,
            SOLDZIP,
            SOLDCOUNTY,
            SOLDCOUNTRY,
            SHIPNAME,
            SHIPLINE1,
            SHIPLINE2,
            SHIPCITY,
            SHIPSTATE,
            SHIPZIP,
            SHIPCOUNTY,
            SHIPCOUNTRY,
            T_Phone.PHONE,
            T_Web.WEB,
            T_Fax.FAX,
            COALESCE(T_Email.EMAIL, T_AccountingContactEmail.EMAIL, T_DefaultContactEmail.EMAIL, T_AnyContactEmail.EMAIL) AS EMAIL,
            T5.PARENTNAME,
            Distr.PARENTID,
            'Customer' AS ACCOUNTTYPE,
            BILLNAME,
            BILLLINE1,
            BILLLINE2,
            BILLCITY,
            BILLSTATE,
            BILLZIP,
            BILLCOUNTY,
            BILLCOUNTRY,
            CAST(ORDERENTRYNOTES AS VARCHAR(4000)) AS ORDERENTRYNOTES,
            CAST(INTERNALNOTES AS VARCHAR(4000)) AS INTERNALNOTES,
            CAST(TERMTEXT AS VARCHAR(4000)) AS TERMTEXT,
            CAST(INVOICETERMTEXT AS VARCHAR(4000)) AS INVOICETERMTEXT,
            CAST(TAXID AS VARCHAR(255)) AS TAXID
        FROM
        (
            SELECT
                DISTRIBUTORID,
                DISPLAYID,
                DISTRIBUTORNAME,
                ACTIVE,
                ROLE,
                CUSTOMERRANK,
                SALESUSERID,
                SOLDNAME,
                SOLDLINE1,
                SOLDLINE2,
                SOLDCITY,
                SOLDSTATE,
                SOLDZIP,
                SOLDCOUNTY,
                SOLDCOUNTRY,
                SHIPNAME,
                SHIPLINE1,
                SHIPLINE2,
                SHIPCITY,
                SHIPSTATE,
                SHIPZIP,
                SHIPCOUNTY,
                SHIPCOUNTRY,
                BILLNAME,
                BILLLINE1,
                BILLLINE2,
                BILLCITY,
                BILLSTATE,
                BILLZIP,
                BILLCOUNTY,
                BILLCOUNTRY,
                CAST(ORDERENTRYNOTES AS VARCHAR(4000)) AS ORDERENTRYNOTES,
                CAST(INTERNALNOTES AS VARCHAR(4000)) AS INTERNALNOTES,
                CAST(TERMTEXT AS VARCHAR(4000)) AS TERMTEXT,
                CAST(INVOICETERMTEXT AS VARCHAR(4000)) AS INVOICETERMTEXT,
                CAST(TAXID AS VARCHAR(255)) AS TAXID,
                UPDATEDATE,
                acc.Id AS PARENTID,
                DEFAULTCONTACTDBID,
                DEFAULTCONTACTID,
                ACCOUNTINGCONTACTDBID,
                ACCOUNTINGCONTACTID
            FROM OASIS_MACSII.oasis.CHSC_DISTRIBUTORS WITH (NOLOCK)
            LEFT JOIN AO.Account acc
                ON PARENTCOMPANY = acc.Cst_External_Id__c
            WHERE CHSC_DISTRIBUTORS.ACTIVE = 'Y'
        ) Distr
        LEFT JOIN
        (
            SELECT DISTRIBUTORID, MAX(PHONENUMBER) AS PHONE
            FROM OASIS_MACSII.oasis.CHSC_DISTRIBUTOR_PHONE WITH (NOLOCK)
            WHERE UPPER(KIND) = 'PHONE'
            GROUP BY DISTRIBUTORID
        ) T_Phone
            ON Distr.DISTRIBUTORID = T_Phone.DISTRIBUTORID
        LEFT JOIN
        (
            SELECT DISTRIBUTORID, MAX(PHONENUMBER) AS WEB
            FROM OASIS_MACSII.oasis.CHSC_DISTRIBUTOR_PHONE WITH (NOLOCK)
            WHERE UPPER(KIND) IN ('WWW', 'WEBSITE')
            GROUP BY DISTRIBUTORID
        ) T_Web
            ON Distr.DISTRIBUTORID = T_Web.DISTRIBUTORID
        LEFT JOIN
        (
            SELECT DISTRIBUTORID, MAX(PHONENUMBER) AS FAX
            FROM OASIS_MACSII.oasis.CHSC_DISTRIBUTOR_PHONE WITH (NOLOCK)
            WHERE UPPER(KIND) LIKE 'FAX%'
            GROUP BY DISTRIBUTORID
        ) T_Fax
            ON Distr.DISTRIBUTORID = T_Fax.DISTRIBUTORID
        LEFT JOIN
        (
            SELECT DISTRIBUTORID, MAX(PHONENUMBER) AS EMAIL
            FROM OASIS_MACSII.oasis.CHSC_DISTRIBUTOR_PHONE WITH (NOLOCK)
            WHERE UPPER(KIND) = 'EMAIL'
            GROUP BY DISTRIBUTORID
        ) T_Email
            ON Distr.DISTRIBUTORID = T_Email.DISTRIBUTORID
        LEFT JOIN
        (
            SELECT
                d.DISTRIBUTORID,
                MAX(cp.PHONENUMBER) AS EMAIL
            FROM OASIS_MACSII.oasis.CHSC_DISTRIBUTORS d WITH (NOLOCK)
            JOIN OASIS_MACSII.oasis.CHSC_CONTACTS c WITH (NOLOCK)
                ON c.DBID = d.ACCOUNTINGCONTACTDBID
               AND c.CONTACTID = d.ACCOUNTINGCONTACTID
               AND ISNULL(c.SUPRESS, 'N') <> 'Y'
            JOIN OASIS_MACSII.oasis.CHSC_CONTACT_PHONE cp WITH (NOLOCK)
                ON cp.DBID = c.DBID
               AND cp.CONTACTID = c.CONTACTID
               AND UPPER(cp.KIND) IN ('EMAIL', 'EM')
            GROUP BY d.DISTRIBUTORID
        ) T_AccountingContactEmail
            ON Distr.DISTRIBUTORID = T_AccountingContactEmail.DISTRIBUTORID
        LEFT JOIN
        (
            SELECT
                d.DISTRIBUTORID,
                MAX(cp.PHONENUMBER) AS EMAIL
            FROM OASIS_MACSII.oasis.CHSC_DISTRIBUTORS d WITH (NOLOCK)
            JOIN OASIS_MACSII.oasis.CHSC_CONTACTS c WITH (NOLOCK)
                ON c.DBID = d.DEFAULTCONTACTDBID
               AND c.CONTACTID = d.DEFAULTCONTACTID
               AND ISNULL(c.SUPRESS, 'N') <> 'Y'
            JOIN OASIS_MACSII.oasis.CHSC_CONTACT_PHONE cp WITH (NOLOCK)
                ON cp.DBID = c.DBID
               AND cp.CONTACTID = c.CONTACTID
               AND UPPER(cp.KIND) IN ('EMAIL', 'EM')
            GROUP BY d.DISTRIBUTORID
        ) T_DefaultContactEmail
            ON Distr.DISTRIBUTORID = T_DefaultContactEmail.DISTRIBUTORID
        LEFT JOIN
        (
            SELECT
                c.DISTRIBUTORID,
                MAX(cp.PHONENUMBER) AS EMAIL
            FROM OASIS_MACSII.oasis.CHSC_CONTACTS c WITH (NOLOCK)
            JOIN OASIS_MACSII.oasis.CHSC_CONTACT_PHONE cp WITH (NOLOCK)
                ON cp.DBID = c.DBID
               AND cp.CONTACTID = c.CONTACTID
               AND UPPER(cp.KIND) IN ('EMAIL', 'EM')
            WHERE c.DISTRIBUTORID IS NOT NULL
              AND ISNULL(c.SUPRESS, 'N') <> 'Y'
            GROUP BY c.DISTRIBUTORID
        ) T_AnyContactEmail
            ON Distr.DISTRIBUTORID = T_AnyContactEmail.DISTRIBUTORID
        LEFT JOIN
        (
            SELECT DISTRIBUTORID, DISTRIBUTORNAME AS PARENTNAME
            FROM OASIS_MACSII.oasis.CHSC_DISTRIBUTORS WITH (NOLOCK)
        ) T5
            ON Distr.PARENTID = T5.DISTRIBUTORID

        UNION ALL

        SELECT
            Distr.MANUFACTURERID AS DISTRIBUTORID,
            DISPLAYID,
            UPDATEDATE,
            MANUFACTURERNAME AS DISTRIBUTORNAME,
            IIF(ACTIVE = 'Y', 'Active', 'Parent') AS ACTIVE,
            'Manufacturer' AS ROLE,
            NULL AS CUSTOMERRANK,
            dbo.GetActiveUserId(CREATEUSERID) AS SALESUSERID,
            MANUFACTURERNAME AS SOLDNAME,
            MAILLINE1 AS SOLDLINE1,
            MAILLINE2 AS SOLDLINE2,
            MAILCITY AS SOLDCITY,
            MAILSTATE AS SOLDSTATE,
            MAILZIP AS SOLDZIP,
            MAILCOUNTY AS SOLDCOUNTY,
            MAILCOUNTRY AS SOLDCOUNTRY,
            '' AS SHIPNAME,
            '' AS SHIPLINE1,
            '' AS SHIPLINE2,
            '' AS SHIPCITY,
            '' AS SHIPSTATE,
            '' AS SHIPZIP,
            '' AS SHIPCOUNTY,
            '' AS SHIPCOUNTRY,
            T_Phone.PHONE,
            T_Web.WEB,
            T_Fax.FAX,
            COALESCE(T_Email.EMAIL, T_AccountingContactEmail.EMAIL, T_DefaultContactEmail.EMAIL, T_AnyContactEmail.EMAIL) AS EMAIL,
            '' AS PARENTNAME,
            PARENTCOMPANY AS PARENTID,
            'Manufacturer' AS ACCOUNTTYPE,
            MANUFACTURERNAME AS BILLNAME,
            REMITLINE1 AS BILLLINE1,
            REMITLINE2 AS BILLLINE2,
            REMITCITY AS BILLCITY,
            REMITSTATE AS BILLSTATE,
            REMITZIP AS BILLZIP,
            REMITCOUNTY AS BILLCOUNTY,
            REMITCOUNTRY AS BILLCOUNTRY,
            CAST(ORDERENTRYNOTES AS VARCHAR(4000)) AS ORDERENTRYNOTES,
            CAST(INTERNALNOTES AS VARCHAR(4000)) AS INTERNALNOTES,
            CAST(TERMTEXT AS VARCHAR(4000)) AS TERMTEXT,
            CAST(CUSTOMERCOPYTERMS AS VARCHAR(4000)) AS INVOICETERMTEXT,
            '' AS TAXID
        FROM
        (
            SELECT
                m.MANUFACTURERID,
                m.DISPLAYID,
                m.MANUFACTURERNAME,
                acc.Id AS PARENTCOMPANY,
                m.MAILLINE1,
                m.MAILLINE2,
                m.MAILCITY,
                m.MAILSTATE,
                m.MAILZIP,
                m.MAILCOUNTY,
                m.MAILCOUNTRY,
                m.REMITLINE1,
                m.REMITLINE2,
                m.REMITCITY,
                m.REMITSTATE,
                m.REMITZIP,
                m.REMITCOUNTY,
                m.REMITCOUNTRY,
                m.CREATEUSERID,
                m.DEFAULTCONTACTDBID,
                m.DEFAULTCONTACTID,
                m.ACCOUNTINGCONTACTDBID,
                m.ACCOUNTINGCONTACTID,
                CAST(m.ORDERENTRYNOTES AS VARCHAR(4000)) AS ORDERENTRYNOTES,
                CAST(m.INTERNALNOTES AS VARCHAR(4000)) AS INTERNALNOTES,
                CAST(m.TERMTEXT AS VARCHAR(4000)) AS TERMTEXT,
                CAST(m.CUSTOMERCOPYTERMS AS VARCHAR(4000)) AS CUSTOMERCOPYTERMS,
                m.UPDATEDATE,
                m.ACTIVE
            FROM OASIS_MACSII.oasis.CHSC_MANUFACTURERS m WITH (NOLOCK)
            LEFT JOIN AO.Account acc
                ON m.PARENTCOMPANY = acc.Cst_External_Id__c
            WHERE m.ACTIVE = 'Y'
        ) Distr
        LEFT JOIN
        (
            SELECT MANUFACTURERID, MAX(PHONENUMBER) AS PHONE
            FROM OASIS_MACSII.oasis.CHSC_MANUFACTURER_PHONE WITH (NOLOCK)
            WHERE UPPER(KIND) = 'PHONE'
            GROUP BY MANUFACTURERID
        ) T_Phone
            ON Distr.MANUFACTURERID = T_Phone.MANUFACTURERID
        LEFT JOIN
        (
            SELECT MANUFACTURERID, MAX(PHONENUMBER) AS WEB
            FROM OASIS_MACSII.oasis.CHSC_MANUFACTURER_PHONE WITH (NOLOCK)
            WHERE UPPER(KIND) IN ('WWW', 'WEBSITE')
            GROUP BY MANUFACTURERID
        ) T_Web
            ON Distr.MANUFACTURERID = T_Web.MANUFACTURERID
        LEFT JOIN
        (
            SELECT MANUFACTURERID, MAX(PHONENUMBER) AS FAX
            FROM OASIS_MACSII.oasis.CHSC_MANUFACTURER_PHONE WITH (NOLOCK)
            WHERE UPPER(KIND) LIKE 'FAX%'
            GROUP BY MANUFACTURERID
        ) T_Fax
            ON Distr.MANUFACTURERID = T_Fax.MANUFACTURERID
        LEFT JOIN
        (
            SELECT MANUFACTURERID, MAX(PHONENUMBER) AS EMAIL
            FROM OASIS_MACSII.oasis.CHSC_MANUFACTURER_PHONE WITH (NOLOCK)
            WHERE UPPER(KIND) = 'EMAIL'
            GROUP BY MANUFACTURERID
        ) T_Email
            ON Distr.MANUFACTURERID = T_Email.MANUFACTURERID
        LEFT JOIN
        (
            SELECT
                m.MANUFACTURERID,
                MAX(cp.PHONENUMBER) AS EMAIL
            FROM OASIS_MACSII.oasis.CHSC_MANUFACTURERS m WITH (NOLOCK)
            JOIN OASIS_MACSII.oasis.CHSC_CONTACTS c WITH (NOLOCK)
                ON c.DBID = m.ACCOUNTINGCONTACTDBID
               AND c.CONTACTID = m.ACCOUNTINGCONTACTID
               AND ISNULL(c.SUPRESS, 'N') <> 'Y'
            JOIN OASIS_MACSII.oasis.CHSC_CONTACT_PHONE cp WITH (NOLOCK)
                ON cp.DBID = c.DBID
               AND cp.CONTACTID = c.CONTACTID
               AND UPPER(cp.KIND) IN ('EMAIL', 'EM')
            GROUP BY m.MANUFACTURERID
        ) T_AccountingContactEmail
            ON Distr.MANUFACTURERID = T_AccountingContactEmail.MANUFACTURERID
        LEFT JOIN
        (
            SELECT
                m.MANUFACTURERID,
                MAX(cp.PHONENUMBER) AS EMAIL
            FROM OASIS_MACSII.oasis.CHSC_MANUFACTURERS m WITH (NOLOCK)
            JOIN OASIS_MACSII.oasis.CHSC_CONTACTS c WITH (NOLOCK)
                ON c.DBID = m.DEFAULTCONTACTDBID
               AND c.CONTACTID = m.DEFAULTCONTACTID
               AND ISNULL(c.SUPRESS, 'N') <> 'Y'
            JOIN OASIS_MACSII.oasis.CHSC_CONTACT_PHONE cp WITH (NOLOCK)
                ON cp.DBID = c.DBID
               AND cp.CONTACTID = c.CONTACTID
               AND UPPER(cp.KIND) IN ('EMAIL', 'EM')
            GROUP BY m.MANUFACTURERID
        ) T_DefaultContactEmail
            ON Distr.MANUFACTURERID = T_DefaultContactEmail.MANUFACTURERID
        LEFT JOIN
        (
            SELECT
                c.MANUFACTURERID,
                MAX(cp.PHONENUMBER) AS EMAIL
            FROM OASIS_MACSII.oasis.CHSC_CONTACTS c WITH (NOLOCK)
            JOIN OASIS_MACSII.oasis.CHSC_CONTACT_PHONE cp WITH (NOLOCK)
                ON cp.DBID = c.DBID
               AND cp.CONTACTID = c.CONTACTID
               AND UPPER(cp.KIND) IN ('EMAIL', 'EM')
            WHERE c.MANUFACTURERID IS NOT NULL
              AND ISNULL(c.SUPRESS, 'N') <> 'Y'
            GROUP BY c.MANUFACTURERID
        ) T_AnyContactEmail
            ON Distr.MANUFACTURERID = T_AnyContactEmail.MANUFACTURERID
    ) srcAccount
    LEFT JOIN AO.Account
        ON srcAccount.DISTRIBUTORID = AO.Account.Cst_External_Id__c
       AND srcAccount.[ROLE] = AO.Account.Cst_Customer_Type__c
       AND srcAccount.ACTIVE = 'Active'
    WHERE srcAccount.DISTRIBUTORNAME NOT LIKE '%DO NOT USE%'
      AND srcAccount.DISTRIBUTORID <> 'PRO-EDMON';
END
GO
