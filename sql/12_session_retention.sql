-- 12 — Retention within a session: share that plays a 2nd and 3rd match

SELECT
  COUNT(DISTINCT sessao_id) AS sessoes,
  COUNTIF(ordem_na_sessao = 2) AS jogaram_a_2a,
  COUNTIF(ordem_na_sessao = 3) AS jogaram_a_3a,
  ROUND(100 * COUNTIF(ordem_na_sessao = 2) / COUNT(DISTINCT sessao_id), 1) AS pct_2a,
  ROUND(100 * COUNTIF(ordem_na_sessao = 3) / COUNT(DISTINCT sessao_id), 1) AS pct_3a
FROM `jump_ellie.partidas`;
