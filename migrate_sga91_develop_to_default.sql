-- Migração estrutural gerada de sga91_develop para sga91_default
-- PostgreSQL 9.1.24; não altera deliberadamente os dados existentes.
-- Revise e faça backup antes da execução.
BEGIN;
-- Validações preventivas: interrompem toda a transação se houver dados incompatíveis.
DO $migration$
BEGIN
  IF EXISTS (SELECT 1 FROM totem.bil_servico WHERE length(srv_descricao) > 100) THEN
    RAISE EXCEPTION 'Não é possível reduzir bil_servico.srv_descricao para varchar(100): existem valores maiores.';
  END IF;
  IF EXISTS (SELECT 1 FROM totem.bil_servico WHERE srv_tipo_emissao IS NULL) THEN
    RAISE EXCEPTION 'Não é possível aplicar NOT NULL em bil_servico.srv_tipo_emissao.';
  END IF;
  IF EXISTS (SELECT 1 FROM totem.bil_servico WHERE uni_id IS NULL) THEN
    RAISE EXCEPTION 'Não é possível aplicar NOT NULL em bil_servico.uni_id.';
  END IF;
END
$migration$;
-- Sequence ausente
CREATE SEQUENCE totem.bil_sabius_propriedades_sab_id_seq INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 NO CYCLE;
-- Tabelas ausentes
CREATE TABLE public.bil_bilhete_encaminhados (
  bil_numero character varying(9),
  cli_cod character varying(38),
  srv_cod character(36),
  spec_cod character(36),
  bil_situacao text,
  situacao_descricao text,
  bil_pai character(36),
  bil_rastreamento_bilhetes_vi totem.bil_rastreamento_bilhetes_vi,
  bil_prioridade integer,
  bil_dh_emissao timestamp without time zone,
  bil_dh_atendimento timestamp without time zone,
  bil_dh_chamada timestamp without time zone,
  bil_dh_finalizacao timestamp without time zone,
  tempoespera time without time zone,
  tempoatendimento time without time zone,
  ope_cod character(36),
  gui_cod character(36)
);
CREATE TABLE totem.bil_agendamento_abertura (
  age_abe_cod character varying(36) NOT NULL,
  age_per_cod character varying(36),
  age_srv_capacidade integer,
  srv_cod character varying(36),
  spec_cod character varying(36),
  age_srv_data_criacao character varying(36),
  ope_cod character varying(36),
  age_abe_dt_inicio timestamp without time zone,
  age_abe_dt_fim timestamp without time zone,
  age_abe_dom boolean,
  age_abe_seg boolean,
  age_abe_ter boolean,
  age_abe_qua boolean,
  age_abe_qui boolean,
  age_abe_sex boolean,
  age_abe_sab boolean,
  age_srv_descricao character varying(100)
);
CREATE TABLE totem.bil_agendamento_periodo (
  age_per_cod character varying(36) NOT NULL,
  age_per_nome character varying(50),
  age_per_hora_inicio time without time zone,
  age_per_hora_fim time without time zone,
  age_per_data_criacao timestamp without time zone,
  ope_cod character varying(36)
);
CREATE TABLE totem.bil_agendamento_servico_hora (
  age_srv_cod character varying(36) NOT NULL,
  age_abe_cod character varying(36),
  age_srv_hora time without time zone,
  cli_cod character varying(36),
  age_hor_situacao character(1),
  age_srv_data_criacao timestamp without time zone DEFAULT now(),
  age_srv_dia timestamp without time zone,
  srv_cod character varying(36),
  spec_cod character varying(36),
  age_per_cod character varying(36)
);
CREATE TABLE totem.bil_categoria (
  cat_cod character varying(36) NOT NULL,
  cat_nome character varying(150)
);
CREATE TABLE totem.bil_operador_categoria (
  cat_cod character varying(36) NOT NULL,
  ope_cod character varying(36) NOT NULL
);
-- Colunas ausentes em tabelas existentes
ALTER TABLE graficos.ain_dashboard ADD COLUMN ain_das_id_2 character varying(36);
ALTER TABLE totem.bil_bilhete ADD COLUMN bil_codigo_controle_rf character varying(20);
ALTER TABLE totem.bil_cliente ADD COLUMN cli_cpf_extensao integer DEFAULT 0;
ALTER TABLE totem.bil_cliente ADD COLUMN ope_cod character(36);
ALTER TABLE totem.bil_template_impressao ADD COLUMN tim_colunas_cabecalho integer;
ALTER TABLE totem.bil_template_impressao ADD COLUMN tim_colunas_corpo integer;
ALTER TABLE totem.bil_template_impressao ADD COLUMN tim_colunas_rodape integer;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_dom boolean;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_hora_fim time without time zone;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_hora_inicio time without time zone;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_qua boolean;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_qui boolean;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_sab boolean;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_seg boolean;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_sex boolean;
ALTER TABLE totem.bil_totem_servico ADD COLUMN srt_ter boolean;
ALTER TABLE totem.bil_unidade ADD COLUMN uni_cartao_obrigatorio boolean;
ALTER TABLE totem.bil_unidade ADD COLUMN uni_cpf_obrigatorio boolean;
-- Diferenças reais de colunas existentes
ALTER TABLE graficos.ain_grafico ALTER COLUMN ain_gra_id_2 TYPE character varying(36);
ALTER TABLE totem.bil_cliente ALTER COLUMN cli_criacao SET DEFAULT now();
ALTER TABLE totem.bil_cliente ALTER COLUMN cli_nome_chamada DROP NOT NULL;
ALTER TABLE totem.bil_guiche ALTER COLUMN gui_ativo DROP DEFAULT;
ALTER TABLE totem.bil_operador ALTER COLUMN ope_data_de_cadastro SET DEFAULT ('now'::text)::date;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_alternar_atendimento_normal DROP DEFAULT;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_alternar_atendimento_pri DROP DEFAULT;
DROP VIEW totem.acompanhamento_op_atend_view;
DROP VIEW totem.acompanhamento_op_oci_view;
DROP VIEW totem.acompanhamento_view;
DROP VIEW totem.bil_tempo_atend_servico_vi;
DROP VIEW totem.bil_tempo_espera_servico_vi;
DROP VIEW totem.bil_tp_atend_serv_vi_pri;
DROP VIEW totem.bil_tp_esp_serv_vi_pri;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_descricao TYPE character varying(100);
SET LOCAL search_path = totem, public, pg_catalog;
CREATE VIEW totem.acompanhamento_op_atend_view AS  SELECT bil_bilhete.ope_cod, bil_operador.ope_nome, (bil_unidade.uni_descricao::text || ' - '::text) || bil_servico.srv_descricao::text AS srv_descricao, bil_bilhete.bil_numero, date_trunc('day'::text, bil_bilhete.bil_dh_emissao) AS consulta1, ( SELECT COALESCE(to_char(avg(x.dados), 'HH24h MIm SSs'::text), '00h 00m 00s'::text) AS tempo
           FROM ( SELECT age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_atendimento) AS dados, bil_bilhete.ope_cod
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND date_trunc('day'::text, bil_bilhete.bil_dh_emissao) = date_trunc('day'::text, now()) AND bil_bilhete.bil_dh_atendimento IS NOT NULL AND bil_bilhete.ope_cod = bil_operador.ope_cod
                  ORDER BY bil_bilhete.bil_dh_chamada DESC) x) AS tempo_atendimento_operador
   FROM bil_bilhete
   JOIN bil_operador ON bil_bilhete.ope_cod = bil_operador.ope_cod
   JOIN bil_servico ON bil_bilhete.srv_cod = bil_servico.srv_cod
   JOIN bil_unidade ON bil_unidade.uni_id::text = bil_servico.uni_id::text
  WHERE date_trunc('day'::text, bil_bilhete.bil_dh_emissao) = date_trunc('day'::text, now()) AND bil_bilhete.bil_situacao = 'E'::bpchar;
CREATE VIEW totem.acompanhamento_op_oci_view AS  SELECT consulta1.ope_cod, consulta1.gui_cod, consulta1.ope_nome, consulta1.usr_codigo
   FROM bil_operador consulta1
  WHERE NOT (EXISTS ( SELECT bil_bilhete.ope_cod, bil_operador.ope_nome, bil_servico.srv_descricao, bil_bilhete.bil_numero
           FROM bil_bilhete
      JOIN bil_operador ON bil_bilhete.ope_cod = bil_operador.ope_cod
   JOIN bil_servico ON bil_bilhete.srv_cod = bil_servico.srv_cod
  WHERE bil_bilhete.bil_situacao = 'E'::bpchar AND bil_bilhete.ope_cod = consulta1.ope_cod)) AND NOT (EXISTS ( SELECT bil_operador.ope_nome
           FROM bil_tempo_pausa
      JOIN bil_tempo_atendimento ON bil_tempo_pausa.tat_cod = bil_tempo_atendimento.tat_cod
   JOIN bil_operador ON bil_tempo_atendimento.ope_cod = consulta1.ope_cod
  WHERE bil_tempo_atendimento.dh_fim_atendimento IS NULL AND bil_tempo_pausa.tea_dh_retorno IS NULL));
CREATE VIEW totem.acompanhamento_view AS  SELECT bil_servico.srv_cod, COALESCE(bil_unidade.uni_descricao::text || ' - '::text, ''::text) || bil_servico.srv_descricao::text AS srv_descricao, ( SELECT date_part('epoch'::text, bil_acompanhamento.aco_tempo_satisfatorio::interval) AS date_part) AS aco_tempo_satisfatorio_em_sgs, ( SELECT date_part('epoch'::text, bil_acompanhamento.aco_tempo_inadequado::interval) AS date_part) AS aco_tempo_inadequado_em_sgs, ( SELECT date_part('epoch'::text, bil_acompanhamento.aco_tempo_otimo::interval) AS date_part) AS aco_tempo_otimo_em_sgs, ( SELECT date_part('epoch'::text, bil_acompanhamento.aco_tempo_satisfatorio_ta::interval) AS date_part) AS aco_temp_satisfat_ta_em_sgs, ( SELECT date_part('epoch'::text, bil_acompanhamento.aco_tempo_inadequado_ta::interval) AS date_part) AS aco_tempo_inad_ta_em_sgs, ( SELECT date_part('epoch'::text, bil_acompanhamento.aco_tempo_otimo_ta::interval) AS date_part) AS aco_tempo_otimo_ta_em_sgs, ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS total
           FROM bil_bilhete
          WHERE bil_bilhete.bil_situacao = 'N'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.ope_cod IS NULL) AS pessoas_fila, ( SELECT COALESCE(to_char(avg(dados.conta), 'HH24h MIm SSs'::text), '00h 00m 00s'::text) AS "coalesce"
           FROM ( SELECT age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) AS conta
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.bil_dh_chamada IS NOT NULL
                  ORDER BY bil_bilhete.bil_dh_chamada DESC
                 LIMIT 30) dados) AS tempo_espera_formatado, ( SELECT date_part('epoch'::text, COALESCE(avg(dados.conta), '00:00:00'::interval)) AS "coalesce"
           FROM ( SELECT age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) AS conta
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.bil_dh_chamada IS NOT NULL
                  ORDER BY bil_bilhete.bil_dh_chamada DESC
                 LIMIT 30) dados) AS tempo_espera_nao_format_em_segs, ( SELECT COALESCE(to_char(avg(dados.conta), 'HH24h MIm SSs'::text), '00h 00m 00s'::text) AS "coalesce"
           FROM ( SELECT age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado::interval AS conta
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.bil_dh_chamada IS NOT NULL
                  ORDER BY bil_bilhete.bil_dh_chamada DESC
                 LIMIT 30) dados) AS tempo_espera_tot_formatado, ( SELECT date_part('epoch'::text, COALESCE(avg(dados.conta), '00:00:00'::interval)) AS "coalesce"
           FROM ( SELECT age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado::interval AS conta
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.bil_dh_chamada IS NOT NULL
                  ORDER BY bil_bilhete.bil_dh_chamada DESC
                 LIMIT 30) dados) AS tempo_esper_tot_n_fomt_em_segs, ( SELECT COALESCE(to_char(avg(dados.conta), 'HH24h MIm SSs'::text), '00h 00m 00s'::text) AS "coalesce"
           FROM ( SELECT age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_primeiro_atendimento) - bil_bilhete.bil_tempo_pausado::interval AS conta
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.bil_dh_chamada IS NOT NULL
                  ORDER BY bil_bilhete.bil_dh_chamada DESC
                 LIMIT 30) dados) AS tempo_atendimento_formatado, ( SELECT date_part('epoch'::text, COALESCE(avg(dados.conta), '00:00:00'::interval)) AS "coalesce"
           FROM ( SELECT age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_primeiro_atendimento) - bil_bilhete.bil_tempo_pausado::interval AS conta
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.bil_dh_chamada IS NOT NULL
                  ORDER BY bil_bilhete.bil_dh_chamada DESC
                 LIMIT 30) dados) AS tempo_atend_n_format_em_segs, ( SELECT COALESCE(to_char(avg(dados.conta), 'HH24h MIm SSs'::text), '00h 00m 00s'::text) AS "coalesce"
           FROM ( SELECT age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_primeiro_atendimento) AS conta
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.bil_dh_chamada IS NOT NULL
                  ORDER BY bil_bilhete.bil_dh_chamada DESC
                 LIMIT 30) dados) AS tempo_tot_atendimento_format, ( SELECT date_part('epoch'::text, COALESCE(avg(dados.conta), '00:00:00'::interval)) AS "coalesce"
           FROM ( SELECT age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_primeiro_atendimento) AS conta
                   FROM bil_bilhete
                  WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND bil_bilhete.bil_dh_chamada IS NOT NULL
                  ORDER BY bil_bilhete.bil_dh_chamada DESC
                 LIMIT 30) dados) AS tempo_atend_tot_n_fmt_em_segs, ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
           FROM bil_bilhete
          WHERE bil_bilhete.bil_situacao = 'P'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod) AS bilhetes_pausados, ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
           FROM bil_bilhete
          WHERE bil_bilhete.bil_situacao = 'E'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod) AS bilhetes_atendimento, ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
           FROM bil_bilhete
          WHERE bil_bilhete.bil_situacao = 'F'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND 
                CASE
                    WHEN bil_servico.srv_reiniciar_senha = 'D'::bpchar THEN date_trunc('day'::text, bil_bilhete.bil_dh_emissao) = date_trunc('day'::text, 'now'::text::date::timestamp without time zone)
                    WHEN bil_servico.srv_reiniciar_senha = 'S'::bpchar THEN date_trunc('week'::text, bil_bilhete.bil_dh_emissao) = date_trunc('week'::text, 'now'::text::date::timestamp without time zone)
                    WHEN bil_servico.srv_reiniciar_senha = 'M'::bpchar THEN date_trunc('month'::text, bil_bilhete.bil_dh_emissao) = date_trunc('month'::text, 'now'::text::date::timestamp without time zone)
                    ELSE date_trunc('year'::text, bil_bilhete.bil_dh_emissao) = date_trunc('year'::text, 'now'::text::date::timestamp without time zone)
                END = true) AS bilhetes_ausentes, 
        CASE
            WHEN bil_servico.srv_reiniciar_senha = 'D'::bpchar THEN ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
               FROM bil_bilhete
              WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND date_trunc('day'::text, bil_bilhete.bil_dh_emissao) = date_trunc('day'::text, 'now'::text::date::timestamp without time zone))
            WHEN bil_servico.srv_reiniciar_senha = 'S'::bpchar THEN ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
               FROM bil_bilhete
              WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND date_trunc('week'::text, bil_bilhete.bil_dh_emissao) = date_trunc('week'::text, 'now'::text::date::timestamp without time zone))
            WHEN bil_servico.srv_reiniciar_senha = 'M'::bpchar THEN ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
               FROM bil_bilhete
              WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND date_trunc('month'::text, bil_bilhete.bil_dh_emissao) = date_trunc('month'::text, 'now'::text::date::timestamp without time zone))
            ELSE ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
               FROM bil_bilhete
              WHERE bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.srv_cod = bil_servico.srv_cod AND date_trunc('year'::text, bil_bilhete.bil_dh_emissao) = date_trunc('year'::text, 'now'::text::date::timestamp without time zone))
        END AS bilhetes_finalizados, 
        CASE
            WHEN bil_servico.srv_reiniciar_senha = 'D'::bpchar THEN ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
               FROM bil_bilhete
              WHERE bil_bilhete.srv_cod = bil_servico.srv_cod AND date_trunc('day'::text, bil_bilhete.bil_dh_emissao) = date_trunc('day'::text, 'now'::text::date::timestamp without time zone))
            WHEN bil_servico.srv_reiniciar_senha = 'S'::bpchar THEN ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
               FROM bil_bilhete
              WHERE bil_bilhete.srv_cod = bil_servico.srv_cod AND date_trunc('week'::text, bil_bilhete.bil_dh_emissao) = date_trunc('week'::text, 'now'::text::date::timestamp without time zone))
            WHEN bil_servico.srv_reiniciar_senha = 'M'::bpchar THEN ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
               FROM bil_bilhete
              WHERE bil_bilhete.srv_cod = bil_servico.srv_cod AND date_trunc('month'::text, bil_bilhete.bil_dh_emissao) = date_trunc('month'::text, 'now'::text::date::timestamp without time zone))
            ELSE ( SELECT COALESCE(count(bil_bilhete.bil_cod), 0::bigint) AS "coalesce"
               FROM bil_bilhete
              WHERE bil_bilhete.srv_cod = bil_servico.srv_cod AND date_trunc('year'::text, bil_bilhete.bil_dh_emissao) = date_trunc('year'::text, 'now'::text::date::timestamp without time zone))
        END AS todos_bilhetes, bil_servico.uni_id
   FROM bil_servico
   LEFT JOIN bil_unidade ON bil_servico.uni_id::text = bil_unidade.uni_id::text
   JOIN bil_acompanhamento ON bil_servico.srv_cod = bil_acompanhamento.srv_cod
  WHERE COALESCE(bil_servico.srv_ativo, true) = true
  ORDER BY bil_unidade.uni_descricao, bil_servico.srv_descricao;
CREATE VIEW totem.bil_tempo_atend_servico_vi AS  SELECT date_part('year'::text, bil_bilhete.bil_dh_atendimento) AS ano, date_part('month'::text, bil_bilhete.bil_dh_atendimento) AS mes, bil_bilhete.srv_cod, count(*)::integer AS qtd_atendimento, sum(
        CASE
            WHEN age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_primeiro_atendimento) < '00:15:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_ate_15_min, sum(
        CASE
            WHEN age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_primeiro_atendimento) >= '00:15:00'::interval AND age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_primeiro_atendimento) <= '00:30:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_15_a_30_min, sum(
        CASE
            WHEN age(bil_bilhete.bil_dh_finalizacao, bil_bilhete.bil_dh_primeiro_atendimento) > '00:30:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_maior_30_min, (bil_unidade.uni_descricao::text || ' - '::text) || bil_servico.srv_descricao::text AS srv_descricao, bil_servico.srv_sigla, bil_servico.srv_sequencial
   FROM bil_bilhete
   JOIN bil_servico ON bil_servico.srv_cod = bil_bilhete.srv_cod
   JOIN bil_unidade ON bil_unidade.uni_id::text = bil_servico.uni_id::text
  WHERE bil_bilhete.bil_dh_atendimento IS NOT NULL AND bil_bilhete.bil_situacao = 'A'::bpchar
  GROUP BY date_part('year'::text, bil_bilhete.bil_dh_atendimento), date_part('month'::text, bil_bilhete.bil_dh_atendimento), bil_bilhete.srv_cod, (bil_unidade.uni_descricao::text || ' - '::text) || bil_servico.srv_descricao::text, bil_servico.srv_sigla, bil_servico.srv_sequencial;
CREATE VIEW totem.bil_tempo_espera_servico_vi AS  SELECT date_part('year'::text, bil_bilhete.bil_dh_atendimento) AS ano, date_part('month'::text, bil_bilhete.bil_dh_atendimento) AS mes, bil_bilhete.srv_cod, count(*)::integer AS qtd_atendimento, sum(
        CASE
            WHEN (age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado)::interval < '00:15:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_ate_15_min, sum(
        CASE
            WHEN (age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado)::interval >= '00:15:00'::interval AND (age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado)::interval <= '00:30:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_15_a_30_min, sum(
        CASE
            WHEN (age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado)::interval > '00:30:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_maior_30_min, (bil_unidade.uni_descricao::text || ' - '::text) || bil_servico.srv_descricao::text AS srv_descricao, bil_servico.srv_sigla, bil_servico.srv_sequencial
   FROM bil_bilhete
   JOIN bil_servico ON bil_servico.srv_cod = bil_bilhete.srv_cod
   JOIN bil_unidade ON bil_unidade.uni_id::text = bil_servico.uni_id::text
  WHERE bil_bilhete.bil_dh_atendimento IS NOT NULL AND bil_bilhete.bil_situacao = 'A'::bpchar
  GROUP BY date_part('year'::text, bil_bilhete.bil_dh_atendimento), date_part('month'::text, bil_bilhete.bil_dh_atendimento), bil_bilhete.srv_cod, (bil_unidade.uni_descricao::text || ' - '::text) || bil_servico.srv_descricao::text, bil_servico.srv_sigla, bil_servico.srv_sequencial;
CREATE VIEW totem.bil_tp_atend_serv_vi_pri AS  SELECT date_part('year'::text, f.bil_dh_atendimento) AS ano, f.bil_prioridade AS prioriade, date_part('month'::text, f.bil_dh_atendimento) AS mes, f.srv_cod, count(*)::integer AS qtd_atendimento, sum(
        CASE
            WHEN age(f.bil_dh_finalizacao, f.bil_dh_primeiro_atendimento) < '00:15:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_ate_15_min, sum(
        CASE
            WHEN age(f.bil_dh_finalizacao, f.bil_dh_primeiro_atendimento) >= '00:15:00'::interval AND age(f.bil_dh_finalizacao, f.bil_dh_primeiro_atendimento) <= '00:30:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_15_a_30_min, sum(
        CASE
            WHEN age(f.bil_dh_finalizacao, f.bil_dh_primeiro_atendimento) > '00:30:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_maior_30_min, (bil_unidade.uni_descricao::text || ' - '::text) || a.srv_descricao::text AS srv_descricao, a.srv_sigla, a.srv_sequencial
   FROM bil_bilhete f
   JOIN bil_servico a ON a.srv_cod = f.srv_cod
   JOIN bil_unidade ON bil_unidade.uni_id::text = a.uni_id::text
  WHERE f.bil_dh_atendimento IS NOT NULL AND f.bil_situacao = 'A'::bpchar AND f.bil_prioridade = f.bil_prioridade
  GROUP BY date_part('year'::text, f.bil_dh_atendimento), f.bil_prioridade, date_part('month'::text, f.bil_dh_atendimento), f.srv_cod, (bil_unidade.uni_descricao::text || ' - '::text) || a.srv_descricao::text, a.srv_sigla, a.srv_sequencial;
CREATE VIEW totem.bil_tp_esp_serv_vi_pri AS  SELECT date_part('year'::text, bil_bilhete.bil_dh_atendimento) AS ano, bil_bilhete.bil_prioridade, date_part('month'::text, bil_bilhete.bil_dh_atendimento) AS mes, bil_bilhete.srv_cod, count(*)::integer AS qtd_atendimento, sum(
        CASE
            WHEN (age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado)::interval < '00:15:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_ate_15_min, sum(
        CASE
            WHEN (age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado)::interval >= '00:15:00'::interval AND (age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado)::interval <= '00:30:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_15_a_30_min, sum(
        CASE
            WHEN (age(bil_bilhete.bil_dh_primeiro_atendimento, bil_bilhete.bil_dh_emissao) + bil_bilhete.bil_tempo_pausado)::interval > '00:30:00'::interval THEN 1
            ELSE 0
        END)::integer AS espera_maior_30_min, (bil_unidade.uni_descricao::text || ' - '::text) || bil_servico.srv_descricao::text AS srv_descricao, bil_servico.srv_sigla, bil_servico.srv_sequencial
   FROM bil_bilhete
   JOIN bil_servico ON bil_servico.srv_cod = bil_bilhete.srv_cod
   JOIN bil_unidade ON bil_unidade.uni_id::text = bil_servico.uni_id::text
  WHERE bil_bilhete.bil_dh_atendimento IS NOT NULL AND bil_bilhete.bil_situacao = 'A'::bpchar AND bil_bilhete.bil_prioridade = bil_bilhete.bil_prioridade
  GROUP BY date_part('year'::text, bil_bilhete.bil_dh_atendimento), bil_bilhete.bil_prioridade, date_part('month'::text, bil_bilhete.bil_dh_atendimento), bil_bilhete.srv_cod, (bil_unidade.uni_descricao::text || ' - '::text) || bil_servico.srv_descricao::text, bil_servico.srv_sigla, bil_servico.srv_sequencial;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_exibir_servico_chamada DROP DEFAULT;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_hora_agendamento DROP DEFAULT;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_multiplas_chamadas DROP DEFAULT;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_senha_nome_pessoa DROP DEFAULT;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_spec_alter_obrigatorio DROP DEFAULT;
ALTER TABLE totem.bil_servico ALTER COLUMN srv_tipo_emissao SET NOT NULL;
ALTER TABLE totem.bil_servico ALTER COLUMN uni_id SET NOT NULL;
ALTER TABLE totem.bil_template_impressao ALTER COLUMN tim_nao_utilizar_especiais DROP DEFAULT;
ALTER TABLE totem.bil_template_impressao ALTER COLUMN tim_utilizar_replaces DROP DEFAULT;
ALTER TABLE totem.bil_unidade ALTER COLUMN uni_active DROP DEFAULT;
-- Primary keys, unique constraints e foreign keys ausentes
ALTER TABLE totem.bil_agendamento_abertura ADD CONSTRAINT bil_agendamento_servico_pkey PRIMARY KEY (age_abe_cod);
ALTER TABLE totem.bil_agendamento_periodo ADD CONSTRAINT bil_agendamento_periodo_pkey PRIMARY KEY (age_per_cod);
ALTER TABLE totem.bil_agendamento_servico_hora ADD CONSTRAINT bil_agendamento_hora_cliente_pkey PRIMARY KEY (age_srv_cod);
ALTER TABLE totem.bil_agendamento_servico_hora ADD CONSTRAINT bil_agendamento_servico_hora_age_per_cod_age_srv_dia_key UNIQUE (age_per_cod, age_srv_dia);
ALTER TABLE totem.bil_agendamento_servico_hora ADD CONSTRAINT bil_agendamento_servico_hora_age_srv_hora_age_srv_dia_key UNIQUE (age_srv_hora, age_srv_dia);
ALTER TABLE totem.bil_categoria ADD CONSTRAINT bil_categoria_pkey PRIMARY KEY (cat_cod);
ALTER TABLE totem.bil_cliente ADD CONSTRAINT bil_cliente_cli_cpf_cli_cpf_extensao_key UNIQUE (cli_cpf, cli_cpf_extensao);
ALTER TABLE totem.bil_cliente ADD CONSTRAINT bil_cliente_ope_cod_fkey FOREIGN KEY (ope_cod) REFERENCES totem.bil_operador(ope_cod) ON DELETE SET NULL;
ALTER TABLE totem.bil_operador_categoria ADD CONSTRAINT bil_operador_categoria_cat_cod_fkey FOREIGN KEY (cat_cod) REFERENCES totem.bil_categoria(cat_cod) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE totem.bil_operador_categoria ADD CONSTRAINT bil_operador_categoria_ope_cod_fkey FOREIGN KEY (ope_cod) REFERENCES totem.bil_operador(ope_cod) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE totem.bil_operador_categoria ADD CONSTRAINT bil_operador_categoria_pkey PRIMARY KEY (cat_cod, ope_cod);
ALTER TABLE totem.etq_estoque ADD CONSTRAINT etq_estoque_cli_cod_fkey FOREIGN KEY (cli_cod) REFERENCES totem.bil_cliente(cli_cod) ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE totem.etq_estoque ADD CONSTRAINT etq_estoque_ope_cod_fkey FOREIGN KEY (ope_cod) REFERENCES totem.bil_operador(ope_cod) ON UPDATE CASCADE ON DELETE SET NULL;
-- Índices ausentes que não são criados pelas constraints acima
CREATE INDEX bil_bilhete_bil_dh_emissao_idx ON totem.bil_bilhete USING btree ((bil_dh_emissao::date));
CREATE INDEX bil_bilhete_cli_cod_idx ON totem.bil_bilhete USING btree (cli_cod);
CREATE INDEX bil_bilhete_expr_idx ON totem.bil_bilhete USING btree ((bil_encaminhados_de IS NULL));
CREATE INDEX bil_bilhete_expr_idx1 ON totem.bil_bilhete USING btree ((bil_encaminhados_de IS NOT NULL));
CREATE INDEX bil_bilhete_srv_cod_idx ON totem.bil_bilhete USING btree (srv_cod);
CREATE INDEX bil_cliente_cli_cpf_cli_cpf_extensao_idx ON totem.bil_cliente USING btree (cli_cpf, cli_cpf_extensao);
CREATE INDEX bil_operador_usr_codigo_idx ON totem.bil_operador USING btree (usr_codigo);
CREATE INDEX bil_tempo_atendimento_dh_fim_atendimento_idx ON totem.bil_tempo_atendimento USING btree (dh_fim_atendimento);
CREATE INDEX bil_tempo_atendimento_dh_inicio_atendimento_idx ON totem.bil_tempo_atendimento USING btree (dh_inicio_atendimento);
CREATE INDEX bil_tempo_atendimento_dh_inicio_atendimento_idx1 ON totem.bil_tempo_atendimento USING btree ((dh_inicio_atendimento::date));
CREATE INDEX bil_tempo_atendimento_gui_cod_idx ON totem.bil_tempo_atendimento USING btree (gui_cod);
-- Recriação dos dois índices com definição divergente
DROP INDEX totem.bil_bilhete_bil_cod_idx1;
CREATE INDEX bil_bilhete_bil_cod_idx1 ON totem.bil_bilhete USING btree (bil_cod DESC);
DROP INDEX totem.bil_bilhete_bil_encaminhados_de_idx1;
CREATE INDEX bil_bilhete_bil_encaminhados_de_idx1 ON totem.bil_bilhete USING btree (bil_encaminhados_de NULLS FIRST);
-- O índice extra da NEW é preservado para evitar remoção potencialmente prejudicial.
COMMIT;
