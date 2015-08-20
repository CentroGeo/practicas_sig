Práctica 3 Análisis de redes con pgrouting
=========

En esta práctica vamos a hacer análisis de rutas utilizando la extensión [pgrouting](http://pgrouting.org/) para PostGis. Lo primero que tenemos que hacer es instalar dicha extensión:

* Del archivo de datos de la práctica (la carpeta debe estar en el escritorio), extrae el contenido de la carpeta `pgrouting-pg92-binaries-2.0.0w64gcc48.zip` y copia los archivos en la ruta de instalación de postgres: `C:\Program Files\PostgreSQL\9.2`

Para probar que la extensión quedó instalada correctamente, desde una consola de sql (conectada a alguna de las bases de datos que hemos utilizado), de pgAdmin escribe:

````sql
CREATE EXTENSION pgrouting;
````

Si la consulta no regresa ningún error, la extensión quedó instalada correctamente.

## Parte I: preparación de los datos

Lo primero que tenemos que hacer es, como siempre, subir nuestro _shape_ a la base de datos. Los datos que vamos a usar están en el archivo `red_utm.shp`. Súbelos en una table que se llame _calles_

##Parte II: Creación de la topología y pesos

Una vez que tenemos las calles que nos interesan, vamos a usar pgrouting para crear la topología de red sobre las calles. Lo primero que necesitamos es agregar dos campos para almacenar los nodos de orígen y destino de cada segmento:

````sql
alter table calles add column source integer;
alter table calles add column target integer;
````

Ahora, vamos a llamar a la función `select pgr_createTopology('lines', tolerancia, 'geom', 'id');`, para crear los nodos y asignar los identificadores correspondientes. Los argumentos de la función son los siguientes:

+ **lines**: Tabla con las geometrías
+ **tolerancia**: Distancia (en las unidades de la proyección) máxima para considerar dos lineas unidas.
+ **geom**: Columna con geometría.
+ **id**: columna con el identificador único.

En nuestro caso:

````sql
select pgr_createTopology('calles', 0.0001, 'geom', 'gid');
````

Como pueden ver, esta función crea la tabla `calles_vertices_pgr`, idealmente esta tabla contiene todos los nodos de la red, examínenla en Qgis.

Ahora, vamos a asignar algunos pesos a las calles, para eso podemos usar (igual que en la práctica de redes de Análisis Espacial), la categoría vial y estimar una velocidad promedio de recorrido a partir de eso. Primero agregamos las columnas que nos faltan:

````sql
alter table calles add column speed float;
alter table calles add column cost float;
````

Ahora vamos a popular los valores de _speed_ utilizando la columna _catvial_ (esto es un ejemplo, fíjate a qué tipo de calle corresponde cada categoría y pon un valor razonable):

````sql
update calles set speed =
case when catvial = 'CUARTO ORDEN' then 10
 when catvial = 'TERCER ORDEN' then 20
 when catvial = 'SEGUNDO ORDEN' then 30
 when catvial = 'PRIMER ORDEN' then 50
 else null end
````

Ahora podemos calcular la columna costo usando el tiempo de viaje:

````sql
update red_calles_utm set cost = ((st_length(geom)/1000)/speed)*(60)
````

Finalmente, para terminar esta parte del ejercicio, vamos a calcular una ruta usando dos algoritmos diferentes, primero vamos a usar [Dijkstra] (http://docs.pgrouting.org/2.0/en/src/dijkstra/doc/index.html#pgr-dijkstra):

````sql
select c.gid, c.geom from calles c,
 (SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         cost::double precision AS cost
                        FROM calles',
                300032, 241417, true, true)) as ruta
where c.gid = ruta.edge
````

Ahora vamos a utilizar  A*, para este algoritmo (heurístico), necesitamos agregar cuatro nuevas columnas y popularlas:

````sql
ALTER TABLE calles
ADD COLUMN x1 double precision,
ADD COLUMN y1 double precision,
ADD COLUMN x2 double precision,
ADD COLUMN y2 double precision;

UPDATE calles SET
x1 = ST_X(ST_startPoint(ST_GeometryN(geom,1))),
y1 = ST_Y(ST_startPoint(ST_GeometryN(geom,1))),
x2 = st_x(st_endpoint(ST_GeometryN(geom,1))),
y2 = st_y(st_endpoint(ST_GeometryN(geom,1)));
````

Ahora sí, podemos utilizar el algoritmo A*:

````sql
select c.gid, c.geom from calles c,
(SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_astar('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         cost::double precision AS cost,
                         x1, y1, x2, y2
                        FROM calles',
                162867, 163952, true, false)
) as ruta
where c.gid = ruta.edge
````
Jueguen un rato con los nodos de inicio y fin, con lo algoritmos de rutas, investiguen y, finalmente, intenten contestar las siguientes preguntas:

##Preguntas

+ Explica las diferencias entre los algoritmos de Dijkstra y A*
+ Bajo qué condiciones recomendarías usar uno u otro algoritmo.
