# Ejercicios varios

Aquí pueden encontrar algunos ejercicios que les resultarán útiles para sus
proyectos de SIG. El objetivo es que tengan una referencia general y que sean
capaces de adaptar estos ejercicios a sus casos de uso.


## Encontrar el nodo de la red más cercano a un punto arbitrario.

Cuando estamos trabajando con redes, un problema que se presenta a menudo es
encontrar el nodo más cercano a un punto dado. Por ejemplo, cuando queremos
calcular la ruta entre dos puntos, lo más probable es que dichos puntos
no sean nodos de la red. Entonces, para calcular la ruta, necesitamos empezar
por encontrar el nodo más cercano.

Para ejemplificar, trabajemos con la red de OSM de la práctica 3 y supongamos
que queremos encontrar la ruta entrelos puntos:

+ Origen: -99.14438, 19.35159
+ Destino: -99.1815, 19.3249

Primero vamos a visualizar los puntos (en un multipoint):

````sql
SELECT 1,ST_collect(ST_SetSRID(ST_MakePoint(-99.18147, 19.32486),4326),
                    ST_SetSRID(ST_MakePoint(-99.1815, 19.3249),4326));
````
Si cargan el resultado de la consulta como una capa en QGIS, podrán ver que
ninguno de los puntos es un nodo de la red. Ahora, vamos a seleccionar el nodo
más cercano al origen, para esto vamos a utilizar el
[operador de distancia](http://postgis.net/docs/geometry_distance_centroid.html) de
PostGis:

````sql
SELECT  gid
FROM ways
ORDER BY the_geom <-> ST_SetSRID(ST_MakePoint(-99.18147, 19.32486),4326)
LIMIT 1;
````
El operador de distancia `<->` regresa la distancia entre dos geometrías
(más específicamente, entre sus _bounding boxes_), aprovechando el índice espacial.
Entonces, si ordenamos los nodos de la red por la distancia al puto y luego
pedimos sólo el primero, acabamos por encontrar el nodo más cercano.

El problema con esta forma de hacerlo es que no resulta muy práctico hacer dos
consultas, apuntar los resultados y luego calcular la ruta. Necesitamos una
forma de _envolver_ el proceso.

## Creando vistas para usar diferentes configuraciones de red.

Recordemos que las redes de OSM contienen arcos de diferentes tipos, entonces,
cuando queremos calcular rutas para un medio de transporte específico, necesitamos
seleccionar los arcos (y nodos) transitables por dicho mkedio de transporte.

Para este ejercicio pensemos en calcular rutas para automóviles. Lo primero que
necesitamos es seleccionar los segmentos que se pueden transitar en auto
(los ids de las clases los obtuve del modelo de datos!):

````sql
SELECT  *
FROM ways
WHERE class_id in (101,102,103,104,105,106,107,108,109,110,111,112,113,114,117,100)
````
Esta es la parte fácil, ahora necesitamos seleccionar los nodos que corresponden.
Para evitar escribir una consulta muy larga, primero vamos a crear una
[vista](https://en.wikipedia.org/wiki/View_(SQL)) con la consulta que acabamos
 de hacer:

````sql
 CREATE VIEW ways_car AS
 SELECT  *
 FROM ways
 WHERE class_id in (101,102,103,104,105,106,107,108,109,110,111,112,113,114,117,100)
````

Desde el punto de vista del usuario, las vistas se portan exáctamente igual que
las tablas, la diferencia es que las vistas prácticamente no ocupan espacio en
el disco duro (hay más razones para usar vistas, pero no es el objetivo aquí).

Ahora sí, ya que tenemos seleccionados y guardados en una vista los arcos que
queremos, vamos a seleccionar los nodos correspondientes:

````sql
select distinct on (v.id) id, v.the_geom
from ways_vertices_pgr v, ways_car w
where st_touches(v.the_geom,w.the_geom)
order by v.id ,random()
````
Como pueden ver esta consulta es mucho más complicada, el problema es que
tenemos que seleccionar los vértices de acuerdo a si son _source_ o _target_,
lo cual implica unir la vista de ways_car dos veces con la tabla de vértices.
Como las tablas son muy grandes, la unión toma mucho tiempo. La ventaja es que
podemos aprovechar las geometrías para seleccionar los nodos que tocan a la red,
debido a los índices espaciales, esa unión es relativamente rápida. El problema
que nos queda por resolver es eliminar los ids de nodo repetidos (¿por qué se repiten?),
 para eso usamos el `distinct on (v.id)` y ordenamos por `random()` (no nos importa
   cuál seleccionesmos, todos son iguales). El problema con esta aproximación es
que, como la consulta es lenta, no nos conviene crear una vista porque eso implica
ejecutarla cada vez que la usemos. Entonces, creemos una tabla:

````sql
create table vertices_ways_car as
select distinct on (v.id) id, v.the_geom
from ways_vertices_pgr v, ways_car w
where st_touches(v.the_geom,w.the_geom)
order by v.id ,random()
````
Y creemos un índice espacial sobre esta tabla para poder buscar eficientemente:

````sql
CREATE INDEX vertices_ways_car_gix ON vertices_ways_car USING GIST (the_geom);
````


## Envolviendo `pgr_dijkstra` en una función.

Supongamos que ya tenemos calculados los pesos de nuestra red y los arcos válidos,
ahora, para economizar en las consultas para calcular rutas, vamos a _encapsular_
la funcionalidad en nuestra propia función.

Primero, de la red de calles vamos a extraer los segmentos que pueden ser
transitados en auto (los ids de las clases los obtuve del modelo de datos!):

Entonces, asumiendo que los pesos los tenemos calculados en una columna,
para cada ruta que calculemos tenemos que pasar esa consulta (o crear una visita,
 pero ese es otro tema). Ademas, como vimos en la sección anterior, no siempre
 tenemos el inicio y fin de la ruta como nodos de la red, entonces, escribamos
 una función que tome las *geometrías* de inicio y fin y regresae la ruta entre
 los nodos más cercanos  

 Como no queremos escribir tanto, vamos a crear una
 función que nos ayude:

````sql
 CREATE OR REPLACE FUNCTION my_dijkstra(
         IN source Point,
         IN target Point,
         OUT seq INTEGER,
         OUT cost FLOAT,
         OUT geom geometry
     )
     RETURNS SETOF record AS
 $BODY$
     WITH
     dijkstra AS (
         SELECT * FROM pgr_dijkstra(
             'SELECT  *
             FROM ways
             WHERE class_id in (101,102,103,104,105,106,107,108,109,110,111,112,113,114,117,100)',
             -- source
             (SELECT id FROM ways_vertices_pgr WHERE osm_id = $2),
             -- target
             (SELECT id FROM ways_vertices_pgr WHERE osm_id = $3))
     )
     SELECT dijkstra.seq, dijkstra.cost, ways.name,
     CASE
         WHEN dijkstra.node = ways.source THEN the_geom
         ELSE ST_Reverse(the_geom)
     END AS route_geom
     FROM dijkstra JOIN ways
     ON (edge = gid) ORDER BY seq;
 $BODY$
 LANGUAGE 'sql';
````
