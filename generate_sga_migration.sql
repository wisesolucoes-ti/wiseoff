SET search_path = pg_catalog;

WITH
missing_tables(schema_name, table_name) AS (
    VALUES
      ('public', 'bil_bilhete_encaminhados'),
      ('totem', 'bil_agendamento_abertura'),
      ('totem', 'bil_agendamento_periodo'),
      ('totem', 'bil_agendamento_servico_hora'),
      ('totem', 'bil_categoria'),
      ('totem', 'bil_operador_categoria')
),
missing_columns(schema_name, table_name, column_name) AS (
    VALUES
      ('graficos', 'ain_dashboard', 'ain_das_id_2'),
      ('totem', 'bil_bilhete', 'bil_codigo_controle_rf'),
      ('totem', 'bil_cliente', 'cli_cpf_extensao'),
      ('totem', 'bil_cliente', 'ope_cod'),
      ('totem', 'bil_template_impressao', 'tim_colunas_cabecalho'),
      ('totem', 'bil_template_impressao', 'tim_colunas_corpo'),
      ('totem', 'bil_template_impressao', 'tim_colunas_rodape'),
      ('totem', 'bil_totem_servico', 'srt_dom'),
      ('totem', 'bil_totem_servico', 'srt_hora_fim'),
      ('totem', 'bil_totem_servico', 'srt_hora_inicio'),
      ('totem', 'bil_totem_servico', 'srt_qua'),
      ('totem', 'bil_totem_servico', 'srt_qui'),
      ('totem', 'bil_totem_servico', 'srt_sab'),
      ('totem', 'bil_totem_servico', 'srt_seg'),
      ('totem', 'bil_totem_servico', 'srt_sex'),
      ('totem', 'bil_totem_servico', 'srt_ter'),
      ('totem', 'bil_unidade', 'uni_cartao_obrigatorio'),
      ('totem', 'bil_unidade', 'uni_cpf_obrigatorio')
),
missing_constraints(schema_name, table_name, constraint_name) AS (
    VALUES
      ('totem', 'bil_agendamento_abertura', 'bil_agendamento_servico_pkey'),
      ('totem', 'bil_agendamento_periodo', 'bil_agendamento_periodo_pkey'),
      ('totem', 'bil_agendamento_servico_hora', 'bil_agendamento_hora_cliente_pkey'),
      ('totem', 'bil_categoria', 'bil_categoria_pkey'),
      ('totem', 'bil_operador_categoria', 'bil_operador_categoria_pkey'),
      ('totem', 'bil_cliente', 'bil_cliente_ope_cod_fkey'),
      ('totem', 'bil_operador_categoria', 'bil_operador_categoria_cat_cod_fkey'),
      ('totem', 'bil_operador_categoria', 'bil_operador_categoria_ope_cod_fkey'),
      ('totem', 'etq_estoque', 'etq_estoque_cli_cod_fkey'),
      ('totem', 'etq_estoque', 'etq_estoque_ope_cod_fkey'),
      ('totem', 'bil_agendamento_servico_hora', 'bil_agendamento_servico_hora_age_per_cod_age_srv_dia_key'),
      ('totem', 'bil_agendamento_servico_hora', 'bil_agendamento_servico_hora_age_srv_hora_age_srv_dia_key'),
      ('totem', 'bil_cliente', 'bil_cliente_cli_cpf_cli_cpf_extensao_key')
),
missing_indexes(schema_name, index_name) AS (
    VALUES
      ('totem', 'bil_agendamento_hora_cliente_pkey'),
      ('totem', 'bil_agendamento_periodo_pkey'),
      ('totem', 'bil_agendamento_servico_hora_age_per_cod_age_srv_dia_key'),
      ('totem', 'bil_agendamento_servico_hora_age_srv_hora_age_srv_dia_key'),
      ('totem', 'bil_agendamento_servico_pkey'),
      ('totem', 'bil_bilhete_bil_dh_emissao_idx'),
      ('totem', 'bil_bilhete_cli_cod_idx'),
      ('totem', 'bil_bilhete_expr_idx'),
      ('totem', 'bil_bilhete_expr_idx1'),
      ('totem', 'bil_bilhete_srv_cod_idx'),
      ('totem', 'bil_categoria_pkey'),
      ('totem', 'bil_cliente_cli_cpf_cli_cpf_extensao_idx'),
      ('totem', 'bil_cliente_cli_cpf_cli_cpf_extensao_key'),
      ('totem', 'bil_operador_categoria_pkey'),
      ('totem', 'bil_operador_usr_codigo_idx'),
      ('totem', 'bil_tempo_atendimento_dh_fim_atendimento_idx'),
      ('totem', 'bil_tempo_atendimento_dh_inicio_atendimento_idx'),
      ('totem', 'bil_tempo_atendimento_dh_inicio_atendimento_idx1'),
      ('totem', 'bil_tempo_atendimento_gui_cod_idx')
),
statements(sort_group, sort_name, sql_text) AS (
    SELECT 10, 'header', '-- Migração estrutural gerada de sga91_develop para sga91_default'
    UNION ALL SELECT 11, 'header', '-- PostgreSQL 9.1.24; não altera deliberadamente os dados existentes.'
    UNION ALL SELECT 12, 'header', '-- Revise e faça backup antes da execução.'
    UNION ALL SELECT 13, 'header', 'BEGIN;'

    UNION ALL SELECT 20, 'preflight', '-- Validações preventivas: interrompem toda a transação se houver dados incompatíveis.'
    UNION ALL SELECT 21, 'preflight', E'DO $migration$\nBEGIN\n  IF EXISTS (SELECT 1 FROM totem.bil_servico WHERE length(srv_descricao) > 100) THEN\n    RAISE EXCEPTION ''Não é possível reduzir bil_servico.srv_descricao para varchar(100): existem valores maiores.'';\n  END IF;\n  IF EXISTS (SELECT 1 FROM totem.bil_servico WHERE srv_tipo_emissao IS NULL) THEN\n    RAISE EXCEPTION ''Não é possível aplicar NOT NULL em bil_servico.srv_tipo_emissao.'';\n  END IF;\n  IF EXISTS (SELECT 1 FROM totem.bil_servico WHERE uni_id IS NULL) THEN\n    RAISE EXCEPTION ''Não é possível aplicar NOT NULL em bil_servico.uni_id.'';\n  END IF;\nEND\n$migration$;'

    UNION ALL SELECT 30, 'sequence', '-- Sequence ausente'
    UNION ALL
    SELECT 31,
           quote_ident(s.sequence_schema) || '.' || quote_ident(s.sequence_name),
           'CREATE SEQUENCE ' || quote_ident(s.sequence_schema) || '.' || quote_ident(s.sequence_name) ||
           ' INCREMENT BY ' || s.increment || ' MINVALUE ' || s.minimum_value ||
           ' MAXVALUE ' || s.maximum_value || ' START WITH ' || s.start_value ||
           CASE WHEN s.cycle_option = 'YES' THEN ' CYCLE;' ELSE ' NO CYCLE;' END
      FROM information_schema.sequences s
     WHERE s.sequence_schema = 'totem'
       AND s.sequence_name = 'bil_sabius_propriedades_sab_id_seq'

    UNION ALL SELECT 40, 'tables', '-- Tabelas ausentes'
    UNION ALL
    SELECT 41,
           quote_ident(n.nspname) || '.' || quote_ident(c.relname),
           'CREATE TABLE ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) || E' (\n' ||
           string_agg(
             '  ' || quote_ident(a.attname) || ' ' || format_type(a.atttypid, a.atttypmod) ||
             CASE WHEN d.adbin IS NOT NULL THEN ' DEFAULT ' || pg_get_expr(d.adbin, d.adrelid) ELSE '' END ||
             CASE WHEN a.attnotnull THEN ' NOT NULL' ELSE '' END,
             E',\n' ORDER BY a.attnum
           ) || E'\n);'
      FROM missing_tables mt
      JOIN pg_namespace n ON n.nspname = mt.schema_name
      JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = mt.table_name AND c.relkind = 'r'
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
 LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  GROUP BY n.nspname, c.relname

    UNION ALL SELECT 50, 'columns', '-- Colunas ausentes em tabelas existentes'
    UNION ALL
    SELECT 51,
           quote_ident(n.nspname) || '.' || quote_ident(c.relname) || '.' || quote_ident(a.attname),
           'ALTER TABLE ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) ||
           ' ADD COLUMN ' || quote_ident(a.attname) || ' ' || format_type(a.atttypid, a.atttypmod) ||
           CASE WHEN d.adbin IS NOT NULL THEN ' DEFAULT ' || pg_get_expr(d.adbin, d.adrelid) ELSE '' END ||
           CASE WHEN a.attnotnull THEN ' NOT NULL' ELSE '' END || ';'
      FROM missing_columns mc
      JOIN pg_namespace n ON n.nspname = mc.schema_name
      JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = mc.table_name AND c.relkind = 'r'
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = mc.column_name AND a.attnum > 0 AND NOT a.attisdropped
 LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum

    UNION ALL SELECT 60, 'column_changes', '-- Diferenças reais de colunas existentes'
    UNION ALL SELECT 61, '01', 'ALTER TABLE graficos.ain_grafico ALTER COLUMN ain_gra_id_2 TYPE character varying(36);'
    UNION ALL SELECT 61, '02', 'ALTER TABLE totem.bil_cliente ALTER COLUMN cli_criacao SET DEFAULT now();'
    UNION ALL SELECT 61, '03', 'ALTER TABLE totem.bil_cliente ALTER COLUMN cli_nome_chamada DROP NOT NULL;'
    UNION ALL SELECT 61, '04', 'ALTER TABLE totem.bil_guiche ALTER COLUMN gui_ativo DROP DEFAULT;'
    UNION ALL SELECT 61, '05', 'ALTER TABLE totem.bil_operador ALTER COLUMN ope_data_de_cadastro SET DEFAULT (''now''::text)::date;'
    UNION ALL SELECT 61, '06', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_alternar_atendimento_normal DROP DEFAULT;'
    UNION ALL SELECT 61, '07', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_alternar_atendimento_pri DROP DEFAULT;'
    UNION ALL SELECT 61, '07a', 'DROP VIEW totem.bil_tp_esp_serv_vi_pri;'
    UNION ALL SELECT 61, '08', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_descricao TYPE character varying(100);'
    UNION ALL SELECT 61, '08a', 'CREATE VIEW totem.bil_tp_esp_serv_vi_pri AS ' || pg_get_viewdef('totem.bil_tp_esp_serv_vi_pri'::regclass, true) || ';'
    UNION ALL SELECT 61, '09', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_exibir_servico_chamada DROP DEFAULT;'
    UNION ALL SELECT 61, '10', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_hora_agendamento DROP DEFAULT;'
    UNION ALL SELECT 61, '11', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_multiplas_chamadas DROP DEFAULT;'
    UNION ALL SELECT 61, '12', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_senha_nome_pessoa DROP DEFAULT;'
    UNION ALL SELECT 61, '13', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_spec_alter_obrigatorio DROP DEFAULT;'
    UNION ALL SELECT 61, '14', 'ALTER TABLE totem.bil_servico ALTER COLUMN srv_tipo_emissao SET NOT NULL;'
    UNION ALL SELECT 61, '15', 'ALTER TABLE totem.bil_servico ALTER COLUMN uni_id SET NOT NULL;'
    UNION ALL SELECT 61, '16', 'ALTER TABLE totem.bil_template_impressao ALTER COLUMN tim_nao_utilizar_especiais DROP DEFAULT;'
    UNION ALL SELECT 61, '17', 'ALTER TABLE totem.bil_template_impressao ALTER COLUMN tim_utilizar_replaces DROP DEFAULT;'
    UNION ALL SELECT 61, '18', 'ALTER TABLE totem.bil_unidade ALTER COLUMN uni_active DROP DEFAULT;'

    UNION ALL SELECT 70, 'constraints', '-- Primary keys, unique constraints e foreign keys ausentes'
    UNION ALL
    SELECT 71,
           quote_ident(n.nspname) || '.' || quote_ident(c.relname) || '.' || quote_ident(con.conname),
           'ALTER TABLE ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) ||
           ' ADD CONSTRAINT ' || quote_ident(con.conname) || ' ' || pg_get_constraintdef(con.oid, true) || ';'
      FROM missing_constraints mc
      JOIN pg_namespace n ON n.nspname = mc.schema_name
      JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = mc.table_name
      JOIN pg_constraint con ON con.conrelid = c.oid AND con.conname = mc.constraint_name

    UNION ALL SELECT 80, 'indexes', '-- Índices ausentes que não são criados pelas constraints acima'
    UNION ALL
    SELECT 81,
           quote_ident(n.nspname) || '.' || quote_ident(ci.relname),
           pg_get_indexdef(i.indexrelid, 0, true) || ';'
      FROM missing_indexes mi
      JOIN pg_namespace n ON n.nspname = mi.schema_name
      JOIN pg_class ci ON ci.relnamespace = n.oid AND ci.relname = mi.index_name AND ci.relkind = 'i'
      JOIN pg_index i ON i.indexrelid = ci.oid
     WHERE NOT EXISTS (SELECT 1 FROM pg_constraint con WHERE con.conindid = i.indexrelid)

    UNION ALL SELECT 90, 'changed_indexes', '-- Recriação dos dois índices com definição divergente'
    UNION ALL SELECT 91, '01', 'DROP INDEX totem.bil_bilhete_bil_cod_idx1;'
    UNION ALL SELECT 91, '02', 'CREATE INDEX bil_bilhete_bil_cod_idx1 ON totem.bil_bilhete USING btree (bil_cod DESC);'
    UNION ALL SELECT 91, '03', 'DROP INDEX totem.bil_bilhete_bil_encaminhados_de_idx1;'
    UNION ALL SELECT 91, '04', 'CREATE INDEX bil_bilhete_bil_encaminhados_de_idx1 ON totem.bil_bilhete USING btree (bil_encaminhados_de NULLS FIRST);'

    UNION ALL SELECT 100, 'footer', '-- O índice extra da NEW é preservado para evitar remoção potencialmente prejudicial.'
    UNION ALL SELECT 101, 'footer', 'COMMIT;'
)
SELECT sql_text
  FROM statements
 ORDER BY sort_group, sort_name;
