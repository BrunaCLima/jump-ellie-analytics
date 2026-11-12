-- 06 — Mean vs median final score
-- PERCENTILE_CONT gives the exact median. APPROX_QUANTILES was used at first,
-- but it returned different values on each run (data-quality issue #6).

SELECT DISTINCT
  AVG(pontuacao) OVER () AS media,
  PERCENTILE_CONT(pontuacao, 0.5) OVER () AS mediana
FROM `jump_ellie.eventos_raw`
WHERE fonte = 'simulado' AND evento = 'morte';
