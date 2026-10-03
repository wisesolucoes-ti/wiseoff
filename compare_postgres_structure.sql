WITH structural_objects AS (
    SELECT 'SCHEMA'::text AS object_type,
           n.nspname::text AS object_name,
           ''::text AS definition
      FROM pg_namespace n
     WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
       AND n.nspname !~ '^pg_temp_'
       AND n.nspname !~ '^pg_toast_temp_'

    UNION ALL

    SELECT 'TABLE',
           quote_ident(n.nspname) || '.' || quote_ident(c.relname),
           'persistence=' || c.relpersistence
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'r'
       AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
       AND n.nspname !~ '^pg_temp_'
       AND n.nspname !~ '^pg_toast_temp_'

    UNION ALL

    SELECT 'SEQUENCE',
           quote_ident(sequence_schema) || '.' || quote_ident(sequence_name),
           'type=' || data_type ||
           ';start=' || start_value ||
           ';min=' || minimum_value ||
           ';max=' || maximum_value ||
           ';increment=' || increment ||
           ';cycle=' || cycle_option
      FROM information_schema.sequences
     WHERE sequence_schema NOT IN ('pg_catalog', 'information_schema', 'pg_toast')

    UNION ALL

    SELECT 'COLUMN',
           quote_ident(n.nspname) || '.' || quote_ident(c.relname) || '.' || quote_ident(a.attname),
           'position=' || a.attnum ||
           ';type=' || pg_catalog.format_type(a.atttypid, a.atttypmod) ||
           ';not_null=' || a.attnotnull ||
           ';default=' || COALESCE(pg_get_expr(d.adbin, d.adrelid), '')
      FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
 LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
     WHERE c.relkind = 'r'
       AND a.attnum > 0
       AND NOT a.attisdropped
       AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
       AND n.nspname !~ '^pg_temp_'
       AND n.nspname !~ '^pg_toast_temp_'

    UNION ALL

    SELECT CASE con.contype
               WHEN 'p' THEN 'PRIMARY_KEY'
               WHEN 'f' THEN 'FOREIGN_KEY'
               WHEN 'u' THEN 'UNIQUE_CONSTRAINT'
               WHEN 'c' THEN 'CHECK_CONSTRAINT'
               WHEN 'x' THEN 'EXCLUSION_CONSTRAINT'
               ELSE 'CONSTRAINT_' || con.contype
           END,
           quote_ident(n.nspname) || '.' || quote_ident(c.relname) || '.' || quote_ident(con.conname),
           pg_get_constraintdef(con.oid, true)
      FROM pg_constraint con
      JOIN pg_class c ON c.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
       AND n.nspname !~ '^pg_temp_'
       AND n.nspname !~ '^pg_toast_temp_'

    UNION ALL

    SELECT 'INDEX',
           quote_ident(n.nspname) || '.' || quote_ident(ci.relname),
           pg_get_indexdef(i.indexrelid, 0, true)
      FROM pg_index i
      JOIN pg_class ct ON ct.oid = i.indrelid
      JOIN pg_class ci ON ci.oid = i.indexrelid
      JOIN pg_namespace n ON n.oid = ct.relnamespace
     WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
       AND n.nspname !~ '^pg_temp_'
       AND n.nspname !~ '^pg_toast_temp_'
)
SELECT object_type, object_name, definition
  FROM structural_objects
 ORDER BY object_type, object_name, definition;
