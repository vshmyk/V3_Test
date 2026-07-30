CREATE SCHEMA IF NOT EXISTS aotransact_pg;

CREATE TABLE IF NOT EXISTS aotransact_pg.dml_audit (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    txid bigint NOT NULL,
    schema_name text NOT NULL,
    table_name text NOT NULL,
    operation text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_row jsonb NULL,
    new_row jsonb NULL,
    statement_sql text NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    session_user_name text NOT NULL DEFAULT session_user,
    application_name text NULL DEFAULT current_setting('application_name', true)
);

CREATE INDEX IF NOT EXISTS ix_dml_audit_recorded_at
    ON aotransact_pg.dml_audit (recorded_at, id);

CREATE OR REPLACE FUNCTION aotransact_pg.get_table_columns(p_schema_name text, p_table_name text)
RETURNS TABLE (
    ordinal_position int,
    column_name text,
    data_type regtype,
    is_primary_key boolean
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        a.attnum::int AS ordinal_position,
        a.attname::text AS column_name,
        a.atttypid::regtype AS data_type,
        EXISTS (
            SELECT 1
            FROM pg_index i
            WHERE i.indrelid = c.oid
              AND i.indisprimary
              AND a.attnum = ANY(i.indkey)
        ) AS is_primary_key
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    JOIN pg_attribute a
      ON a.attrelid = c.oid
    WHERE n.nspname = p_schema_name
      AND c.relname = p_table_name
      AND c.relkind = 'r'
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY a.attnum;
$$;

CREATE OR REPLACE FUNCTION aotransact_pg.format_jsonb_literal(p_value jsonb, p_type regtype)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_text text;
BEGIN
    IF p_value IS NULL OR p_value = 'null'::jsonb THEN
        RETURN 'NULL';
    END IF;

    v_text := p_value #>> '{}';

    IF p_type::text = 'bytea' THEN
        IF v_text LIKE '\x%' THEN
            RETURN format('decode(%L, ''hex'')', substr(v_text, 3));
        END IF;

        RETURN format('decode(%L, ''escape'')', v_text);
    END IF;

    RETURN quote_literal(v_text);
END;
$$;

CREATE OR REPLACE FUNCTION aotransact_pg.build_insert_sql(p_schema_name text, p_table_name text, p_new_row jsonb)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_columns text[];
    v_values text[];
    v_column record;
BEGIN
    v_columns := ARRAY[]::text[];
    v_values := ARRAY[]::text[];

    FOR v_column IN
        SELECT *
        FROM aotransact_pg.get_table_columns(p_schema_name, p_table_name)
    LOOP
        v_columns := array_append(v_columns, format('%I', v_column.column_name));
        v_values := array_append(
            v_values,
            aotransact_pg.format_jsonb_literal(p_new_row -> v_column.column_name, v_column.data_type)
        );
    END LOOP;

    RETURN format(
        'INSERT INTO %I.%I (%s) VALUES (%s);',
        p_schema_name,
        p_table_name,
        array_to_string(v_columns, ', '),
        array_to_string(v_values, ', ')
    );
END;
$$;

CREATE OR REPLACE FUNCTION aotransact_pg.build_delete_sql(p_schema_name text, p_table_name text, p_old_row jsonb)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_where_parts text[];
    v_pk_parts text[];
    v_all_parts text[];
    v_column record;
BEGIN
    v_pk_parts := ARRAY[]::text[];
    v_all_parts := ARRAY[]::text[];

    FOR v_column IN
        SELECT *
        FROM aotransact_pg.get_table_columns(p_schema_name, p_table_name)
    LOOP
        v_all_parts := array_append(
            v_all_parts,
            format(
                '%I IS NOT DISTINCT FROM %s',
                v_column.column_name,
                aotransact_pg.format_jsonb_literal(p_old_row -> v_column.column_name, v_column.data_type)
            )
        );

        IF v_column.is_primary_key THEN
            v_pk_parts := array_append(
                v_pk_parts,
                format(
                    '%I IS NOT DISTINCT FROM %s',
                    v_column.column_name,
                    aotransact_pg.format_jsonb_literal(p_old_row -> v_column.column_name, v_column.data_type)
                )
            );
        END IF;
    END LOOP;

    v_where_parts := CASE
        WHEN array_length(v_pk_parts, 1) IS NOT NULL THEN v_pk_parts
        ELSE v_all_parts
    END;

    RETURN format(
        'DELETE FROM %I.%I WHERE %s;',
        p_schema_name,
        p_table_name,
        array_to_string(v_where_parts, ' AND ')
    );
END;
$$;

CREATE OR REPLACE FUNCTION aotransact_pg.build_update_sql(
    p_schema_name text,
    p_table_name text,
    p_old_row jsonb,
    p_new_row jsonb)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_set_parts text[];
    v_set_fallback text[];
    v_pk_parts text[];
    v_all_parts text[];
    v_column record;
BEGIN
    v_set_parts := ARRAY[]::text[];
    v_set_fallback := ARRAY[]::text[];
    v_pk_parts := ARRAY[]::text[];
    v_all_parts := ARRAY[]::text[];

    FOR v_column IN
        SELECT *
        FROM aotransact_pg.get_table_columns(p_schema_name, p_table_name)
    LOOP
        v_all_parts := array_append(
            v_all_parts,
            format(
                '%I IS NOT DISTINCT FROM %s',
                v_column.column_name,
                aotransact_pg.format_jsonb_literal(p_old_row -> v_column.column_name, v_column.data_type)
            )
        );

        IF v_column.is_primary_key THEN
            v_pk_parts := array_append(
                v_pk_parts,
                format(
                    '%I IS NOT DISTINCT FROM %s',
                    v_column.column_name,
                    aotransact_pg.format_jsonb_literal(p_old_row -> v_column.column_name, v_column.data_type)
                )
            );
        ELSE
            v_set_fallback := array_append(
                v_set_fallback,
                format(
                    '%I = %s',
                    v_column.column_name,
                    aotransact_pg.format_jsonb_literal(p_new_row -> v_column.column_name, v_column.data_type)
                )
            );

            IF (p_old_row -> v_column.column_name) IS DISTINCT FROM (p_new_row -> v_column.column_name) THEN
                v_set_parts := array_append(
                    v_set_parts,
                    format(
                        '%I = %s',
                        v_column.column_name,
                        aotransact_pg.format_jsonb_literal(p_new_row -> v_column.column_name, v_column.data_type)
                    )
                );
            END IF;
        END IF;
    END LOOP;

    IF array_length(v_set_parts, 1) IS NULL THEN
        v_set_parts := v_set_fallback;
    END IF;

    RETURN format(
        'UPDATE %I.%I SET %s WHERE %s;',
        p_schema_name,
        p_table_name,
        array_to_string(v_set_parts, ', '),
        array_to_string(
            CASE WHEN array_length(v_pk_parts, 1) IS NOT NULL THEN v_pk_parts ELSE v_all_parts END,
            ' AND '
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION aotransact_pg.capture_dml_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_row jsonb;
    v_new_row jsonb;
    v_statement_sql text;
BEGIN
    IF TG_TABLE_SCHEMA = 'aotransact_pg' THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_new_row := to_jsonb(NEW);
        v_statement_sql := aotransact_pg.build_insert_sql(TG_TABLE_SCHEMA, TG_TABLE_NAME, v_new_row);

        INSERT INTO aotransact_pg.dml_audit (txid, schema_name, table_name, operation, old_row, new_row, statement_sql)
        VALUES (txid_current(), TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, NULL, v_new_row, v_statement_sql);

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        v_old_row := to_jsonb(OLD);
        v_new_row := to_jsonb(NEW);
        v_statement_sql := aotransact_pg.build_update_sql(TG_TABLE_SCHEMA, TG_TABLE_NAME, v_old_row, v_new_row);

        INSERT INTO aotransact_pg.dml_audit (txid, schema_name, table_name, operation, old_row, new_row, statement_sql)
        VALUES (txid_current(), TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, v_old_row, v_new_row, v_statement_sql);

        RETURN NEW;
    END IF;

    IF TG_OP = 'DELETE' THEN
        v_old_row := to_jsonb(OLD);
        v_statement_sql := aotransact_pg.build_delete_sql(TG_TABLE_SCHEMA, TG_TABLE_NAME, v_old_row);

        INSERT INTO aotransact_pg.dml_audit (txid, schema_name, table_name, operation, old_row, new_row, statement_sql)
        VALUES (txid_current(), TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, v_old_row, NULL, v_statement_sql);

        RETURN OLD;
    END IF;

    RAISE EXCEPTION 'Unsupported TG_OP: %', TG_OP;
END;
$$;

CREATE OR REPLACE PROCEDURE aotransact_pg.install_capture_triggers(
    p_schema_names text[] DEFAULT ARRAY['dbo', 'oasis'])
LANGUAGE plpgsql
AS $$
DECLARE
    v_table record;
BEGIN
    FOR v_table IN
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_schema = ANY(p_schema_names)
        ORDER BY table_schema, table_name
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS trg_aotransact_pg_capture_dml ON %I.%I;',
            v_table.table_schema,
            v_table.table_name
        );

        EXECUTE format(
            'CREATE TRIGGER trg_aotransact_pg_capture_dml
             AFTER INSERT OR UPDATE OR DELETE ON %I.%I
             FOR EACH ROW
             EXECUTE FUNCTION aotransact_pg.capture_dml_trigger();',
            v_table.table_schema,
            v_table.table_name
        );
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION aotransact_pg.audit_commit_time(p_row_xmin xid, p_recorded_at timestamptz)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF current_setting('track_commit_timestamp', true) = 'on' THEN
        RETURN COALESCE(pg_xact_commit_timestamp(p_row_xmin), p_recorded_at);
    END IF;

    RETURN p_recorded_at;
END;
$$;

CREATE OR REPLACE FUNCTION aotransact_pg.export_recent_trn_lines(p_window interval DEFAULT interval '15 minutes')
RETURNS TABLE (
    sort_key bigint,
    line_no int,
    line text
)
LANGUAGE sql
STABLE
AS $$
    WITH recent_rows AS (
        SELECT
            a.id,
            a.txid,
            a.operation,
            a.schema_name,
            a.table_name,
            a.statement_sql,
            aotransact_pg.audit_commit_time(a.xmin, a.recorded_at) AS commit_time
        FROM aotransact_pg.dml_audit a
        WHERE aotransact_pg.audit_commit_time(a.xmin, a.recorded_at) >= now() - p_window
        ORDER BY aotransact_pg.audit_commit_time(a.xmin, a.recorded_at), a.id
    )
    SELECT id * 10 + 1 AS sort_key,
           1 AS line_no,
           format('--%s-%s-%s', upper(operation), txid, lpad(id::text, 10, '0')) AS line
    FROM recent_rows
    UNION ALL
    SELECT id * 10 + 2 AS sort_key,
           2 AS line_no,
           format(
               '-- commit_time=%s table=%I.%I',
               to_char(commit_time AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.MS "UTC"'),
               schema_name,
               table_name
           ) AS line
    FROM recent_rows
    UNION ALL
    SELECT id * 10 + 3 AS sort_key,
           3 AS line_no,
           statement_sql AS line
    FROM recent_rows
    UNION ALL
    SELECT id * 10 + 4 AS sort_key,
           4 AS line_no,
           'GO' AS line
    FROM recent_rows
    ORDER BY sort_key;
$$;

CREATE OR REPLACE PROCEDURE aotransact_pg.write_recent_trn(
    p_window interval DEFAULT interval '15 minutes',
    p_output_path text DEFAULT 'C:/ERPLINK/FLUX/flux.trn')
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE format(
        'COPY (
            SELECT line
            FROM aotransact_pg.export_recent_trn_lines(%L::interval)
            ORDER BY sort_key
         ) TO %L WITH (FORMAT text)',
        p_window::text,
        p_output_path
    );
END;
$$;

CREATE OR REPLACE PROCEDURE aotransact_pg.purge_audit_rows(p_keep interval DEFAULT interval '7 days')
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM aotransact_pg.dml_audit
    WHERE aotransact_pg.audit_commit_time(xmin, recorded_at) < now() - p_keep;
END;
$$;
