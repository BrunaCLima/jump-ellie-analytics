-- 03 — The 10 players with the most matches

SELECT jogador_id, COUNT(DISTINCT partida_id) AS partidas
FROM `jump_ellie.eventos_raw`
WHERE fonte = 'simulado'
GROUP BY jogador_id
ORDER BY partidas DESC
LIMIT 10;
