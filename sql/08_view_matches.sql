-- 08 — View `partidas`: one row per match, built from the raw events
-- The raw table has one row per event (match start, catnip, evolution, death, quit).
-- This view pivots them into one row per match; every later query reads from it.
-- terminou = the match ended in a death. ordem_na_sessao = 1st, 2nd, 3rd... match of the session.

CREATE OR REPLACE VIEW `jump_ellie.partidas` AS
WITH base AS (
  SELECT
    partida_id,
    jogador_id,
    sessao_id,
    variante,
    MIN(IF(evento = 'partida_inicio', ts_cliente, NULL)) AS inicio,
    COUNTIF(evento = 'catnip') AS catnips,
    COUNTIF(evento = 'evolucao') AS evolucoes,
    MAX(IF(evento = 'morte', pontuacao, NULL)) AS pontuacao_final,
    MAX(IF(evento = 'morte', duracao_s, NULL)) AS duracao_s,
    MAX(IF(evento = 'morte', vilao, NULL)) AS vilao_que_matou,
    COUNTIF(evento = 'morte') > 0 AS terminou
  FROM `jump_ellie.eventos_raw`
  WHERE fonte = 'simulado'
  GROUP BY partida_id, jogador_id, sessao_id, variante
)
SELECT
  *,
  ROW_NUMBER() OVER (PARTITION BY sessao_id ORDER BY inicio) AS ordem_na_sessao
FROM base;
