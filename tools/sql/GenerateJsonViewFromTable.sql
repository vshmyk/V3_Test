/*
    Generate a flattening view over a table that stores one JSON document per row.

    Typical use for your case:
      - source table: CENTERA.dbo.Products
      - JSON column: set @JsonColumn if you know it, otherwise leave NULL for auto-detect
      - key column: set @KeyColumn if you know it, otherwise leave NULL for auto-detect

    What it does:
      1. Resolves the source object
      2. Auto-detects the JSON column and key column when not supplied
      3. Reads one non-null JSON row from the source table
      4. Discovers top-level JSON properties
      5. Infers a reasonable SQL type for each property
      6. Generates a CREATE OR ALTER VIEW statement using OPENJSON ... WITH (...)

    Notes:
      - This flattens top-level properties only.
      - Nested objects/arrays are exposed as JSON text columns via "AS JSON".
      - Type inference is sample-based, so widen or adjust generated types if needed.
      - Set @Execute = 0 to print the generated view first.
*/

SET NOCOUNT ON;

DECLARE @SourceSchema sysname = N'dbo';
DECLARE @SourceTable  sysname = N'Products';
DECLARE @JsonColumn   sysname = NULL;            -- set if known; otherwise auto-detect
DECLARE @KeyColumn    sysname = NULL;            -- set if known; otherwise auto-detect
DECLARE @ViewSchema   sysname = N'dbo';
DECLARE @ViewName     sysname = N'vw_Products_FromJson';
DECLARE @Execute      bit     = 0;               -- 0 = print/select, 1 = create/alter the view

DECLARE @QualifiedSource nvarchar(517) =
    QUOTENAME(@SourceSchema) + N'.' + QUOTENAME(@SourceTable);
DECLARE @QualifiedView nvarchar(517) =
    QUOTENAME(@ViewSchema) + N'.' + QUOTENAME(@ViewName);
DECLARE @SourceObjectId int = OBJECT_ID(@QualifiedSource);

DECLARE @SampleJson nvarchar(max);
DECLARE @SampleSql nvarchar(max);
DECLARE @CandidateSql nvarchar(max);
DECLARE @ResolvedJsonColumn sysname = @JsonColumn;
DECLARE @ResolvedKeyColumn sysname = @KeyColumn;

IF @SourceObjectId IS NULL
BEGIN
    THROW 50000, 'Source table was not found. Check @SourceSchema and @SourceTable, and run the script in the correct database.', 1;
END;

IF @ResolvedJsonColumn IS NULL
BEGIN
    DROP TABLE IF EXISTS #JsonColumnCandidates;

    CREATE TABLE #JsonColumnCandidates
    (
        ColumnName sysname NOT NULL PRIMARY KEY,
        JsonRowCount bigint NOT NULL
    );

    SELECT
        @CandidateSql =
            STRING_AGG(
                CAST(
                    N'INSERT INTO #JsonColumnCandidates (ColumnName, JsonRowCount)
SELECT N''' + REPLACE(c.[name], N'''', N'''''') + N''',
       COUNT_BIG(*)
FROM ' + @QualifiedSource + N'
WHERE ' + QUOTENAME(c.[name]) + N' IS NOT NULL
  AND ISJSON(TRY_CAST(' + QUOTENAME(c.[name]) + N' AS nvarchar(max))) = 1;'
                    AS nvarchar(max)
                ),
                CHAR(13) + CHAR(10)
            )
    FROM sys.columns AS c
    JOIN sys.types AS t
        ON t.user_type_id = c.user_type_id
    WHERE c.[object_id] = @SourceObjectId
      AND t.[name] IN (N'nvarchar', N'varchar', N'nchar', N'char', N'text', N'ntext');

    IF @CandidateSql IS NOT NULL
    BEGIN
        EXEC sys.sp_executesql @CandidateSql;

        SELECT TOP (1)
            @ResolvedJsonColumn = ColumnName
        FROM #JsonColumnCandidates
        WHERE JsonRowCount > 0
        ORDER BY JsonRowCount DESC, ColumnName;
    END;
END;

IF @ResolvedJsonColumn IS NULL
BEGIN
    THROW 50000, 'Could not auto-detect a JSON column. Set @JsonColumn explicitly to the column that stores the JSON document.', 1;
END;

IF COL_LENGTH(@QualifiedSource, @ResolvedJsonColumn) IS NULL
BEGIN
    THROW 50000, 'The supplied @JsonColumn was not found in the source table.', 1;
END;

IF @ResolvedKeyColumn IS NULL
BEGIN
    SELECT TOP (1)
        @ResolvedKeyColumn = c.[name]
    FROM sys.indexes AS i
    JOIN sys.index_columns AS ic
        ON ic.[object_id] = i.[object_id]
       AND ic.index_id = i.index_id
       AND ic.key_ordinal = 1
    JOIN sys.columns AS c
        ON c.[object_id] = ic.[object_id]
       AND c.column_id = ic.column_id
    WHERE i.[object_id] = @SourceObjectId
      AND i.is_primary_key = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM sys.index_columns AS ic2
          WHERE ic2.[object_id] = i.[object_id]
            AND ic2.index_id = i.index_id
            AND ic2.key_ordinal > 1
      );

    IF @ResolvedKeyColumn IS NULL
    BEGIN
        SELECT TOP (1)
            @ResolvedKeyColumn = c.[name]
        FROM sys.columns AS c
        WHERE c.[object_id] = @SourceObjectId
          AND c.is_identity = 1
        ORDER BY c.column_id;
    END;
END;

SET @SampleSql = N'
SELECT TOP (1)
    @SampleJsonOut = CAST(' + QUOTENAME(@ResolvedJsonColumn) + N' AS nvarchar(max))
FROM ' + @QualifiedSource + N'
WHERE ' + QUOTENAME(@ResolvedJsonColumn) + N' IS NOT NULL
  AND ISJSON(TRY_CAST(' + QUOTENAME(@ResolvedJsonColumn) + N' AS nvarchar(max))) = 1' +
CASE
    WHEN NULLIF(@ResolvedKeyColumn, N'') IS NOT NULL
        THEN N'
ORDER BY ' + QUOTENAME(@ResolvedKeyColumn)
    ELSE N''
END + N';';

EXEC sys.sp_executesql
    @SampleSql,
    N'@SampleJsonOut nvarchar(max) OUTPUT',
    @SampleJsonOut = @SampleJson OUTPUT;

IF @SampleJson IS NULL
BEGIN
    THROW 50000, 'No valid JSON rows were found in the source table. Check @SourceSchema, @SourceTable, and @JsonColumn.', 1;
END;

DROP TABLE IF EXISTS #JsonColumns;

CREATE TABLE #JsonColumns
(
    JsonKey        nvarchar(4000) NOT NULL,
    SampleValue    nvarchar(max)  NULL,
    JsonType       int            NOT NULL,
    SqlType        nvarchar(128)  NOT NULL,
    JsonPath       nvarchar(4000) NOT NULL,
    IsJsonFragment bit            NOT NULL
);

INSERT INTO #JsonColumns
(
    JsonKey,
    SampleValue,
    JsonType,
    SqlType,
    JsonPath,
    IsJsonFragment
)
SELECT
    j.[key],
    j.[value],
    j.[type],
    CASE
        WHEN j.[type] = 3 THEN N'bit'
        WHEN j.[type] = 2 AND TRY_CONVERT(int, j.[value]) IS NOT NULL THEN N'int'
        WHEN j.[type] = 2 AND TRY_CONVERT(bigint, j.[value]) IS NOT NULL THEN N'bigint'
        WHEN j.[type] = 2 THEN N'decimal(38, 10)'
        WHEN j.[type] = 1 AND TRY_CONVERT(uniqueidentifier, j.[value]) IS NOT NULL THEN N'uniqueidentifier'
        WHEN j.[type] = 1 AND TRY_CONVERT(datetime2(7), j.[value]) IS NOT NULL THEN N'datetime2(7)'
        WHEN j.[type] = 1 AND LEN(j.[value]) <= 4000 THEN N'nvarchar(4000)'
        WHEN j.[type] IN (4, 5) THEN N'nvarchar(max)'
        ELSE N'nvarchar(max)'
    END,
    N'$."' + REPLACE(j.[key], N'"', N'\"') + N'"',
    CASE WHEN j.[type] IN (4, 5) THEN 1 ELSE 0 END
FROM OPENJSON(@SampleJson) AS j;

IF NOT EXISTS (SELECT 1 FROM #JsonColumns)
BEGIN
    THROW 50001, 'The sample JSON document has no top-level properties to project.', 1;
END;

DECLARE @WithClause nvarchar(max);
DECLARE @ProjectedColumns nvarchar(max);
DECLARE @ViewSql nvarchar(max);

SELECT
    @WithClause =
        STRING_AGG(
            N'    ' + QUOTENAME(JsonKey) + N' ' + SqlType + N' ''' + JsonPath + N'''' +
            CASE WHEN IsJsonFragment = 1 THEN N' AS JSON' ELSE N'' END,
            N',' + CHAR(13) + CHAR(10)
        ) WITHIN GROUP (ORDER BY JsonKey),
    @ProjectedColumns =
        STRING_AGG(N'    j.' + QUOTENAME(JsonKey), N',' + CHAR(13) + CHAR(10))
        WITHIN GROUP (ORDER BY JsonKey)
FROM #JsonColumns;

SET @ViewSql =
    N'CREATE OR ALTER VIEW ' + @QualifiedView + N'
AS
SELECT
' +
    CASE
        WHEN NULLIF(@ResolvedKeyColumn, N'') IS NOT NULL
            THEN N'    src.' + QUOTENAME(@ResolvedKeyColumn) + N',' + CHAR(13) + CHAR(10)
            ELSE N''
    END +
    @ProjectedColumns + N'
FROM ' + @QualifiedSource + N' AS src
OUTER APPLY OPENJSON(src.' + QUOTENAME(@ResolvedJsonColumn) + N')
WITH
(
' + @WithClause + N'
) AS j
WHERE src.' + QUOTENAME(@ResolvedJsonColumn) + N' IS NOT NULL
  AND ISJSON(TRY_CAST(src.' + QUOTENAME(@ResolvedJsonColumn) + N' AS nvarchar(max))) = 1;';

IF @Execute = 1
BEGIN
    EXEC sys.sp_executesql @ViewSql;
END;

SELECT
    @QualifiedSource AS SourceObject,
    @ResolvedJsonColumn AS ResolvedJsonColumn,
    @ResolvedKeyColumn AS ResolvedKeyColumn;

SELECT @ViewSql AS GeneratedViewSql;
PRINT @ViewSql;
