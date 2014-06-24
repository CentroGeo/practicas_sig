
--Esta primera sección contiene las consultas del README, si ya las
--ejecutaste no es necesario que las vuelvas a correr.

--Crear la extensión pgrouting
create extension pgrouting;
--PREPARACIÓN DE DATOS:
--Crear las columnas source y target
ALTER TABLE practica_3.calles_zmvm ADD COLUMN source integer;
ALTER TABLE practica_3.calles_zmvm ADD COLUMN target integer;


--Ahora vamos a agregar una columna con la longitud de cada segmento:

ALTER TABLE practica_3.calles_zmvm ADD COLUMN length numeric;
UPDATE practica_3.calles_zmvm SET length = st_length(geom)

--Crear la topología de redes
SELECT pgr_createTopology('practica_3.calles_zmvm', 0.001,'geom','gid');

--Antes de continuar, creemos unos índices a las columnas source y target para
--hacer búsquedas más eficientes (Esto es importante porque al crear la topología
--sustituimos las búsquedas espaciales por búsqueedas relacionales)
CREATE INDEX source_idx ON practica_3.calles_zmvm("source");
CREATE INDEX target_idx ON practica_3.calles_zmvm("target");

--Ahora vamos a crear una columna que represente el costo, pensemos en el tiempo
--que toma recorrer el segmento caminando:

ALTER TABLE practica_3.calles_zmvm ADD COLUMN tiempo_caminando DOUBLE PRECISION;
UPDATE practica_3.calles_zmvm SET tiempo_caminando = st_length(geom)/0.55

--¿A que velocidad estamos suponiendo que camina una persona?
--Modifique a su gusto
--Como estamos modelando redes 'caminando', la dirección de las calles no
--importa y podemos asumir que el costo en 'reversa' es el mismo. Agreguemos
--esto a la tabla:

 ALTER TABLE practica_3.calles_zmvm ADD COLUMN reverse_cost DOUBLE PRECISION;
 UPDATE practica_3.calles_zmvm SET reverse_cost = tiempo_caminando

--Ahora sí podemos empezar a calcular rutas. Primero usemos el algoritmo Dijkstra:
--Seleccionen los nodos en Qgis
 SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         tiempo_caminando::double precision AS cost,
                         reverse_cost
                        FROM practica_3.calles_zmvm',
                300032, 241417, true, true);

--Nota: revisen la documentación de pgrouting para entender la consulta anterior

--Para visualizar estos resultados necesitamos traer la geometría de la tabla
--calles_zmvm:

select c.gid, c.geom from practica_3.calles_zmvm c,
 (SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         tiempo_caminando::double precision AS cost,
                         reverse_cost
                        FROM practica_3.calles_zmvm',
                300032, 241417, true, true)) as ruta
where c.gid = ruta.edge

-- Dijkstra es sólo uno de los algoritmos que se usan para calcular rutas,
--de hecho es el más 'primitivo'. Ahora vamos a usar otro algoritmo conocido como A*.
--Para usar este algoritmo necesitamos las coordenadas de los puntos de inicio y
-- fin para cada segmento:

ALTER TABLE practica_3.calles_zmvm
ADD COLUMN x1 double precision,
ADD COLUMN y1 double precision,
ADD COLUMN x2 double precision,
ADD COLUMN y2 double precision;

UPDATE practica_3.calles_zmvm SET
x1 = ST_X(ST_startPoint(ST_GeometryN(geom,1))),
y1 = ST_Y(ST_startPoint(ST_GeometryN(geom,1))),
x2 = st_x(st_endpoint(ST_GeometryN(geom,1))),
y2 = st_y(st_endpoint(ST_GeometryN(geom,1)));
 --Noten que tuvimos que usar ST_GeometryN(geom,1) porque los segmentos son del
 --tipo MULTILINESTRING. Chequen que en realidad todos los segmentos contienen
 --sólo una geometría:
SELECT ST_NumGeometries(geom) AS num FROM practica_3.calles_zmvm ORDER BY num


--Ahora podemos calcular rutas usando A*
SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_astar('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         length::double precision AS cost,
                         reverse_cost,
                         x1, y1, x2, y2
                        FROM practica_3.calles_zmvm',
                300032, 300032, true, true);

--Jueguen con los dos algoritmos, comparen tiempos de ejecución para diferentes
--parejas de nodos.
