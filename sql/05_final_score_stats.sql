-- 05 — Final score: mean, min and max

SELECT AVG(pontuacao) AS media, MIN(pontuacao) AS minima, MAX(pontuacao) AS maxima
FROM `jump_ellie.eventos_raw`
WHERE evento = 'morte' AND fonte = 'simulado';
