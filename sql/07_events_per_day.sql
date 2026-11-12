-- 07 — Events per day (Sao Paulo time zone)

SELECT DATE(recebido_em, 'America/Sao_Paulo') AS dia, COUNT(*) AS eventos
FROM `jump_ellie.eventos_raw`
WHERE fonte = 'simulado'
GROUP BY dia
ORDER BY dia;
