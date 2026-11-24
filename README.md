# Parser CYK para Validación de Sintaxis JSON en PostgreSQL

Este proyecto implementa el algoritmo Cocke-Younger-Kasami (CYK) en un motor de base de datos relacional (PostgreSQL) mediante rutinas almacenadas en PL/pgSQL. El objetivo principal es verificar la pertenencia de cadenas de texto al lenguaje generado por una Gramática Libre de Contexto (GLC) representativa de estructuras JSON.

---

## Documento Teórico del Proyecto

El desarrollo formal completo —incluyendo la definición de la gramática original, las derivaciones, los árboles de parsing y la aplicación secuencial de los algoritmos de normalización hasta llegar a la Forma Normal de Chomsky (FNC)— se encuentra detallado en el documento de trabajo:

* [Documento Teórico y Memoria Técnica en Google Docs](https://docs.google.com/document/d/1049ZTX21Y0utFC7p2borzFTnK-b_bLa4AZc-BKBjvps/edit?tab=t.0)

---

## Principio de Funcionamiento

El algoritmo CYK opera mediante programación dinámica y requiere estrictamente que la gramática se encuentre en Forma Normal de Chomsky, donde cada regla de producción adopta una de dos formas:
1. Regla terminal: A -> a (produce exactamente un símbolo terminal).
2. Regla binaria: A -> B C (produce exactamente dos variables no terminales).

El flujo de procesamiento se estructura de la siguiente manera:
1. **Caso base (longitud 1):** Para cada posición i de la cadena de entrada w de longitud n, se determinan las variables no terminales que producen directamente el carácter terminal w[i] mediante reglas del tipo A -> a. Estas variables se insertan en las celdas de la diagonal principal (i, i) de la tabla `matriz_cyk`.
2. **Paso inductivo (longitudes 2 a n):** Se analizan de forma incremental todas las subcadenas posibles de longitud k. Para cada partición intermedia, se consultan las celdas previamente calculadas y se buscan reglas binarias A -> B C tales que B pertenezca al prefijo y C al sufijo de la partición.
3. **Criterio de aceptación:** Una vez completada la matriz, la cadena se considera sintácticamente válida (devuelve `true`) si y solo si el símbolo inicial de la gramática (S) pertenece al conjunto de variables de la celda raíz (1, n). En caso contrario, se rechaza (devuelve `false`).

---

## Estructura de Scripts y Orden de Ejecución

El repositorio organiza el ciclo de vida de la base de datos en 5 scripts modulares que deben ejecutarse de forma secuencial:

* **`01_crear_base_de_datos.sql`**:  
  Sentencia DDL para inicializar la base de datos `tp_cyk`.

* **`02_crear_tablas.sql`**:  
  Define los esquemas relacionales requeridos:
  * `GLC_en_FNC`: Almacena el conjunto de producciones normalizadas diferenciadas por tipo (terminal o binaria) e indexadas para optimizar las consultas del paso inductivo.
  * `matriz_cyk`: Almacena las celdas triangulares de parsing (coordenadas i, j) junto con el arreglo de variables no terminales asociadas (`text[]`).

* **`03_cargar_gramatica.sql`**:  
  Inserta el conjunto de reglas en FNC que describen la sintaxis JSON (delimitadores de objetos `{` y `}`, pares clave-valor, cadenas de texto, números naturales, espacios y anidamiento recursivo).

* **`04_funciones_cyk.sql`**:  
  Implementa la lógica del parser en PL/pgSQL:
  * `setear_matriz(fila integer)`: Función auxiliar modular que computa un nivel específico de la matriz combinando celdas inferiores mediante sentencias SQL con `generate_series` y agregaciones de arreglos.
  * `cyk(cadena text)`: Función principal que orquesta la inicialización del caso base, la invocación de `setear_matriz` y la evaluación del símbolo inicial en la celda superior.

* **`05_probar_parser.sql`**:  
  Contiene las consultas para inspeccionar la gramática cargada, una consulta con agrupación y formateo de texto para renderizar la pirámide triangular de la matriz resultante, y un banco de pruebas automatizadas con casos representativos (cadenas válidas con objetos vacíos, valores numéricos, strings y estructuras anidadas, así como casos inválidos con errores sintácticos de llaves no cerradas, omisión de comillas o claves mal formadas).

---

## Guía Rápida de Uso

Una vez conectado a la base de datos `tp_cyk` y habiendo ejecutado los scripts del 02 al 04, la validación se invoca directamente desde cualquier cliente SQL:

```sql
-- Caso válido: objeto con clave y número
SELECT cyk('{"a":10}');
-- Retorna: true

-- Caso inválido: falta de valor tras el separador de clave
SELECT cyk('{"a":}');
-- Retorna: false
```


#### Iniciar DB en Docker
```bash
docker rm -f postgres-cyk 2>/dev/null; \
docker run --name postgres-cyk -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=tp_cyk -p 5432:5432 -d postgres:16 && \
sleep 3 && \
for f in scripts/02*.sql scripts/03*.sql scripts/04*.sql; do
  docker exec -i postgres-cyk psql -U postgres -d tp_cyk < "$f"
done
```

#### Probar string custom
```bash
docker exec -i postgres-cyk psql -U postgres -d tp_cyk -c "SELECT cyk('{\"a\":10,\"b\":''hola'',\"c\":{},\"df\":{\"gh\":20}}');"
```

#### Ver matriz
```bash
docker exec -i postgres-cyk psql -U postgres -d tp_cyk -c "SELECT (j - i + 1) AS nivel, string_agg('X[' || i || ',' || j || ']=' || array_to_string(x, ','), ' | ' ORDER BY i) AS celdas FROM matriz_cyk WHERE cardinality(x) > 0 GROUP BY (j - i + 1) ORDER BY (j - i + 1) DESC;"
```


## Windows

#### Iniciar DB en Docker
```powershell
docker rm -f postgres-cyk 2>$null
docker run --name postgres-cyk -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=tp_cyk -p 5432:5432 -d postgres:16
Start-Sleep -Seconds 3
Get-ChildItem scripts/02*.sql, scripts/03*.sql, scripts/04*.sql | Sort-Object Name | ForEach-Object {
    Get-Content $_.FullName -Raw | docker exec -i postgres-cyk psql -U postgres -d tp_cyk
}
```

#### Probar string custom
```powershell
'SELECT cyk(''{"a":10,"b":''''hola'''',"c":{},"df":{"gh":20}}'');' | docker exec -i postgres-cyk psql -U postgres -d tp_cyk
```

#### Ver matriz
```powershell
"SELECT (j - i + 1) AS nivel, string_agg('X[' || i || ',' || j || ']=' || array_to_string(x, ','), ' | ' ORDER BY i) AS celdas FROM matriz_cyk WHERE cardinality(x) > 0 GROUP BY (j - i + 1) ORDER BY (j - i + 1) DESC;" | docker exec -i postgres-cyk psql -U postgres -d tp_cyk
```