-- Consultas y pruebas del parser CYK

-- Reglas cargadas en la gramatica
SELECT 
    parte_izq || ' -> ' || 
    CASE 
        WHEN tipo_produccion = 1 THEN quote_literal(parte_der1)
        WHEN tipo_produccion = 2 THEN parte_der1 || ' ' || parte_der2
    END AS regla,
    CASE 
        WHEN tipo_produccion = 1 THEN 'Terminal'
        WHEN tipo_produccion = 2 THEN 'Binaria'
    END AS tipo,
    CASE 
        WHEN start THEN 'Si'
        ELSE 'No'
    END AS es_inicial
FROM GLC_en_FNC
ORDER BY start DESC, parte_izq;

-- Prueba individual y visualizacion de la matriz triangular
SELECT cyk('{"a":10}') AS es_valido;
-- SELECT cyk('{"a":10,"b":''hola'',"c":{},"df":{"gh":20}}') AS es_valido;

SELECT 
    (j - i + 1) AS nivel,
    string_agg(
        'X[' || i || ',' || j || ']=' || 
        CASE 
            WHEN cardinality(x) = 0 THEN '-'
            ELSE array_to_string(x, ',')
        END,
        '  |  ' ORDER BY i
    ) AS celdas
FROM matriz_cyk
GROUP BY (j - i + 1)
ORDER BY (j - i + 1) DESC;

-- Bateria de pruebas
WITH pruebas(id, descripcion, entrada, resultado_esperado) AS (
    VALUES
        (1, 'Objeto simple con numero',                  '{"a":10}',                          true),
        (2, 'Varios pares, texto y string vacio',        '{"a":''hola'',"b":''chau'',"c":''''}', true),
        (3, 'Objeto anidado adentro de otro',            '{"a":{"b":''''}}',                  true),
        (4, 'Objeto vacio',                              '{}',                                true),
        (5, 'Clave sin comillas dobles',                 '{a:10}',                           false),
        (6, 'Llave sin cerrar',                          '{"a":10',                           false),
        (7, 'Falta el valor',                            '{"a":}',                            false),
        (8, 'Espacio indebido en la clave',              '{" a":10}',                         false)
)
SELECT 
    id,
    descripcion,
    entrada,
    cyk(entrada) AS resultado_obtenido,
    resultado_esperado,
    CASE 
        WHEN cyk(entrada) = resultado_esperado THEN 'Correcto'
        ELSE 'Fallo'
    END AS estado
FROM pruebas
ORDER BY id;
