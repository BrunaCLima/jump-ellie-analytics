-- 04 — How many players played 1, 2, 3... matches

WITH por_jogador AS (
  SELECT jogador_id, COUNT(DISTINCT partida_id) AS partidas
  FROM `jump_ellie.eventos_raw`
  WHERE fonte = 'simulado'
  GROUP BY jogador_id
)
SELECT partidas, COUNT(*) AS jogadores
FROM por_jogador
GROUP BY partidas
ORDER BY partidas;
