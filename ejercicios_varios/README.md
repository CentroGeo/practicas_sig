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
que queremos encontrar la ruta entre los puntos:

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
Entonces, si ordenamos los nodos de la red por la distancia al punto y luego
pedimos sólo el primero, acabamos por encontrar el nodo más cercano.

## Redes para automóviles y redes para peatones.

Leyendo la [documentación de OSM](documentación de OSM) podemos ver que los
 datos que tenemos contienen arcos de diferentes tipos y que no todos ellos
 son transitables en todos los medios de transporte. Entonces, para obtener una red para un medio de transporte específico, es necesario extraer los arcos transitables en dicho modo.

En este caso vamos a extraer una red para automóviles. El primer paso es obtener las clases de arcos que forman parte de la red que queremos:

````sql
SELECT * FROM osm_way_classes;
````

````
class_id | type_id |       name        | priority | default_maxspeed
----------+---------+-------------------+----------+------------------
201 |       2 | lane              |        1 |               50
204 |       2 | opposite          |        1 |               50
203 |       2 | opposite_lane     |        1 |               50
202 |       2 | track             |        1 |               50
120 |       1 | bridleway         |        1 |               50
116 |       1 | bus_guideway      |        1 |               50
121 |       1 | byway             |        1 |               50
118 |       1 | cycleway          |        1 |               50
119 |       1 | footway           |        1 |               50
111 |       1 | living_street     |        1 |               50
101 |       1 | motorway          |        1 |               50
103 |       1 | motorway_junction |        1 |               50
102 |       1 | motorway_link     |        1 |               50
117 |       1 | path              |        1 |               50
114 |       1 | pedestrian        |        1 |               50
106 |       1 | primary           |        1 |               50
107 |       1 | primary_link      |        1 |               50
110 |       1 | residential       |        1 |               50
100 |       1 | road              |        1 |               50
108 |       1 | secondary         |        1 |               50
124 |       1 | secondary_link    |        1 |               50
...
````
Otra vez, consultando la [sección pertinente de la documentación](http://wiki.openstreetmap.org/wiki/Map_Features#Highway), podemos ver que los arcos por los que pueden circular automóviles son los que tienen las siguientes clases: 101,102,103,104,105,106,107,108,109,110,111,112,113,114,117,100. En sql:

````sql
SELECT  *
FROM ways
WHERE class_id in (101,102,103,104,105,106,107,108,109,110,111,112,113,114,117,100)
````
Ahora bien, podríamos crear una [vista](https://en.wikipedia.org/wiki/View_(SQL)) con la consulta que acabamos
 de hacer y trabajar sobre ella, eso nos ahorraría espacio en disco a costa de una poca de velocidad en las consultas. Sin embargo, el principal problema de usar una vista es la relación con la tabla de nodos. La tabla `ways_vertices_pgr` contiene nodos que no pertenecen a la red para automóviles, entonces, habría que construir una vista también para esa tabla, el problema es que para seleccionar los nodos que sí están el la red para autos, la consulta es mucho más lenta (involucra una doble unión, ya que el id del nodo viene tanto en la columna `source` como en la columna `target` de la tabla `ways`).

 Para ahorrarnos tiempo en las consultas de *pgrouting* vamos a crear tablas separadas para las nuevas redes, empecemos con los arcos:

 ````sql
CREATE TABLE ways_car AS
SELECT  *
FROM ways
WHERE class_id in (101,102,103,104,105,106,107,108,109,110,111,112,113,114,117,100)
 ````

Recordemos que vamos a necesitar índices sobre la geometria y sobre las columnas `source` y `target`:

````sql
CREATE INDEX ways_car_gix ON ways_car USING GIST (the_geom);
CREATE INDEX ways_car_source_ix ON ways_car (source);
CREATE INDEX ways_car_target_ix ON ways_car (target);
````

Ahora necesitamos crear la tabla con los vértices. Para hacer esto tenemos seleccionar de la tabla `ways_vertices_pgr` sólo los vértices que corresponden a la red `ways_car`:

````sql
CREATE TABLE vertices_ways_car AS
SELECT DISTINCT ON (v.id) id, v.the_geom
FROM ways_vertices_pgr v, ways_car w
WHERE st_touches(v.the_geom,w.the_geom)
ORDER BY v.id ,random()
````
Como pueden ver esta consulta es mucho más complicada, el problema es que
tenemos que seleccionar los vértices de acuerdo a si son _source_ o _target_,
lo cual implica unir la tabla de `ways_car` dos veces con la tabla de vértices.
Como las tablas son muy grandes, la unión toma mucho tiempo. La ventaja es que
podemos aprovechar las geometrías para seleccionar los nodos que tocan a la red,
debido a los índices espaciales, esa unión es relativamente rápida. El problema
que nos queda por resolver es eliminar los ids de nodo repetidos (¿por qué se repiten?),
 para eso usamos el `distinct on (v.id)` y ordenamos por `random()` (no nos importa cuál seleccionemos, todos son iguales).

 Ya sólo nos resta crear los índices sobre la nueva tabla para buscar eficientemente:

 ````sql
CREATE INDEX vertices_ways_car_gix ON vertices_ways_car USING GIST (the_geom);
CREATE INDEX vertices_ways_car__ix ON vertices_ways_car (id);
 ````
Listo! Ya podemos usar las nuevas tablas para trabajar sobre rutas para automóviles

### Una nota sobre los costos (y los costos en reversa)

En el [ejercicio 3](https://github.com/CentroGeo/practicas_sig/tree/master/practica_3) creamos costos para la red en horas pico:

````sql
alter table ways_car add column velocidad_pico float;
update ways_car set velocidad_pico =
  case
    when class_id in(101,102,103) then maxspeed_forward/8
    when class_id in(106,107,108) then maxspeed_forward/4
    else maxspeed_forward/2
  end;
````

Eso nos da la velocidad *en el sentido de la calle*, pero todavía falta el costo en reversa. Para esto, símplemente vamos a agregar una columna que tenga la _velocidad_ en reversa (recordemos que el costo es en tiempo). En esta columna vamos a conservar el valor que tenemos en la columna `velociodad_pico` cuando la vialidad es de doble sentido y el negativo en caso contrario:

````sql
alter table ways_car add column velocidad_pico_reversa float;
update ways_car set velocidad_pico_reversa =
  case
    when one_way = 0 then velocidad_pico
    when one_way = 1 then -1*velocidad_pico
    else velocidad_pico
  end;
````
Ahora sí, cuando queramos hacer rutas para automóviles y usar el costo en reversa, podemos calcularlo con la columna `velocidad_pico_reversa`:

````sql
SELECT seq, id1 AS node, id2 AS edge, cost
  FROM pgr_astar(
    'SELECT
      gid AS id,
      source::integer,
      target::integer,
      (st_length(the_geom::geography)/1000)/velocidad_pico::double precision AS cost,
      (st_length(the_geom::geography)/1000)/velocidad_pico_reversa::double precision AS reverse_cost,
      x1,
      y1,
      x2,
      y2
    FROM ways_car',
  36198, 2064, true, true)
````


## Areas de servicio.

Para encontrar el area de servicio alrededor de un punto necesitamos conocer todos los nodos de la red que quedan a un menos de un determinado _costo_ del nodo origen. Pgrouting provee una función para este tipo de análisis [`pgr_drivingDistance`](http://docs.pgrouting.org/2.2/en/src/driving_distance/doc/pgr_drivingDistance.html#pgr-drivingdistance). Como ejemplo, vamos a encontrar el area de servicio de 10 minutos manejando alrededor del nodo 22084:

````sql
SELECT * FROM pgr_drivingDistance(
      'SELECT gid as id, source, target,
       (st_length(the_geom::geography)/1000)/velocidad_pico as cost,
       (st_length(the_geom::geography)/1000)/velocidad_pico_reversa as reverse_cost
       FROM ways_car',
      22048, 0.16
    );
````
````
seq  |  node  |  edge  |         cost         |      agg_cost       
------+--------+--------+----------------------+---------------------
   1 |  22048 |     -1 |                    0 |                   0
   2 |  50328 |   5524 |  0.00262031610675908 | 0.00262031610675908
   3 |  49371 |   1576 |  0.00399309275550152 | 0.00399309275550152
   4 |  52949 |   1577 | 0.000144054900617303 | 0.00413714765611882
   5 |  45843 |  30524 | 0.000735422841744566 | 0.00487257049786339
   6 |  32082 |  30522 |  0.00258588582051136 | 0.00520620192727044
   7 |  10987 |  55433 |  0.00414090725881317 | 0.00676122336557225
   8 |   4437 |   5525 |   0.0041427142192962 | 0.00676303032605528
   9 |  25315 |  55431 |  0.00256812948621027 | 0.00777433141348072
  10 |  67445 |  51410 |  0.00364581125033538 |  0.0077829589064542
  11 |   6251 |  80343 |  0.00408019054977009 | 0.00928639247704053
  12 |  68346 |  30523 |  0.00254571454203188 | 0.00930874486808717
  13 |  41405 |  26547 |  0.00160747182661866 | 0.00939043073307286
  14 |  43149 |   5523 |  0.00161872109343317 | 0.00939305250691389
  15 |  75047 |  55434 |  0.00223422684003564 |  0.0100085582535164
  16 |  26708 |  30525 |  0.00371864617209659 |  0.0104816764981519
  17 |  75150 |  80345 |   0.0012133737557301 |  0.0105221186238173
  18 |  20512 |  52479 |  0.00187677352505297 |  0.0112672042581258
  19 |  44592 |   5526 |  0.00409222163262525 |   0.011866553046106
  20 | 177552 | 259365 |  0.00521958857232535 |  0.0119808119378976
  21 | 148300 | 217846 |  0.00106111406044257 |  0.0130419259983402
  ...
````

En este caso sencillo, lo que nos regresa `pgr_drivingDistance` es la lista de nodos (columna `node` en el resultado) que quedan a un costo menor o igual al seleccionado. La columna `cost` es el costo involucrado en cruzar el último arco (`edge` en el resultado), mientras que `agg_cost` es el costo agregado para llegar al nodo.

Ahora, para dibujar el polígono que corresponde a la envolvente de los puntos, es decir, el area de servicio, necesitamos convertir los nodos en un polígono. La manera mas sencilla de hacer esto es utilizando la [envolvente convexa](https://en.wikipedia.org/wiki/Convex_hull) de los puntos. Para esto, primero es necesario unir los ids con sus respectivas geometrías:

````sql
select * from vertices_ways_car v,
(SELECT node FROM pgr_drivingDistance(
        'SELECT gid as id, source, target,
         (st_length(the_geom::geography)/1000)/velocidad_pico as cost,
         (st_length(the_geom::geography)/1000)/velocidad_pico_reversa as reverse_cost
         FROM ways_car',
        22048, 0.16
      )) as service
where v.id = service.node
````

Ahora necesitamos _colectar_ los puntos para calcular su envolvente:

````sql
select ST_collect(v.the_geom) from vertices_ways_car v,
(SELECT node FROM pgr_drivingDistance(
        'SELECT gid as id, source, target,
         (st_length(the_geom::geography)/1000)/velocidad_pico as cost,
         (st_length(the_geom::geography)/1000)/velocidad_pico_reversa as reverse_cost
         FROM ways_car',
        22048,0.16
      )) as service
where v.id = service.node
````

Y ahora que ya tenemos la colección, se la pasamos a `st_convexHull` para obtener el polígono:

````sql
select st_convexHull(ST_collect(v.the_geom)) as geom,1 as id from vertices_ways_car v,
(SELECT node FROM pgr_drivingDistance(
        'SELECT gid as id, source, target,
         (st_length(the_geom::geography)/1000)/velocidad_pico as cost,
         (st_length(the_geom::geography)/1000)/velocidad_pico_reversa as reverse_cost
         FROM ways_car',
        22048,0.16
      )) as service
where v.id = service.node
````
El problema con esta aproximación es que, por definición, `st_convexHull` nos devuelve un polígono convexo, lo que implica que, en general, vamos a seleccionar puntos que no quedan a un costo menor que el que seleccionamos. Para resolver este problema y obtener polígonos que representen el problema con más fidelidad, `pgrouting` provee la función ` pgr_pointsAsPolygon` que usa el concepto de [_Alpha Shape_](https://en.wikipedia.org/wiki/Alpha_shape) para obtener una envolvente cóncava de los puntos. Primero, guardamos el resultado en una tabla:

````sql
create table servicio as
select * from vertices_ways_car v,
(SELECT node FROM pgr_drivingDistance(
        'SELECT gid as id, source, target,
         (st_length(the_geom::geography)/1000)/velocidad_pico as cost,
         (st_length(the_geom::geography)/1000)/velocidad_pico_reversa as reverse_cost
         FROM ways_car',
        22048, 0.16
      )) as service
where v.id = service.node

````
Y luego utilizamos ` pgr_pointsAsPolygon` para encontrar la envolvente cóncava.

````sql
select 1 as id,
pgr_pointsAsPolygon(
    'select id::integer,st_x(the_geom) as x,
            st_y(the_geom) as y from servicio') as geom
````


## Trabajar en masa (y rápido)

Entre las ventajas de usar bases de datos tenemos que, por un lado, permiten la automatización de procesos que, de hacerse a mano, tomarían mucho tiempo y, por otro lado, al estar muy optimizadas, son capaces de realizar las consultas en tiempos relativamente cortos. En esta sección vamos a explorar un poco estas capacidades estudiando como extender los ejemplos anteriores para trabajar con múltiples nodos.

### Encontrando los nodos más cercanos a muchos puntos.

Hasta ahora vimos cómo encontrar el nodo de la red más cercano a un punto dado, pero ¿Qué pasa si quiero hacerlo para muchos puntos? El procedimiento es muy similar al caso de un solo punto, el problema es que, para que el operador `<->` use el índice espacial, la geometría de referencia (el punto para el cual queremos encontrar el nodo más cercano) debe permanecer constante.

 Afortunadamente, podemos usar una [sub-consulta correlacionada](https://en.wikipedia.org/wiki/Correlated_subquery) para darle la vuelta a ese problema. Esto quiere decir que vamos a usar una subconsulta que regrese un valor (en este caso la geometría de referencia) por cada renglón de la consulta exterior (los nodos de la red).

Supongamos que tenemos una capa `facilities` con los puntos que queremos asignar a los nodos más cercanos, entonces, para realizar la asignación usando el operador `<->` y aprovechando el índice espacial, hacemos:

````sql
select f.id as facility, (
  SELECT n.id
  FROM vertices_ways_car As n
  ORDER BY f.geom <-> n.the_geom LIMIT 1
)as closest_node
from facilities f
````

Como pueden ver, la subconsulta (la parte que está encerrada en paréntesis) se ejecuta una vez por cada renglón de la tabla `facilities`, lo que permite que, desde el punto de vista del operador de distancia, la geometría de referencia permanezca constante.

### Encontrando el area de servicio alrededor de cada punto.

Ya que tenemos una forma de asignar los puntos de la tabla `facilities` a los nodos de la red, veamos como calcular el area de servicio para cada uno de esos nodos.

Como vimos antes, para calcular el area de servicio alrededor de un punto podemos hacer:

````sql
SELECT * FROM pgr_drivingDistance(
      'SELECT gid as id, source, target,
       (st_length(the_geom::geography)/1000)/velocidad_pico as cost,
       (st_length(the_geom::geography)/1000)/velocidad_pico_reversa as reverse_cost
       FROM ways_car',
      22048, 0.16
    );
````

Con lo que obtenemos (entre otras cosas) los ids de los puntos que quedan a un consto menor o igual al especificado. El problema ahora es cómo hacer esto para todos los puntos contenidos, por ejemplo, en la capa facilities. El primer paso es crear una tabla con la relación entre los puntos y los nodos:

````sql
create table nodes_facilities as
select f.id as facility, (
  SELECT n.id
  FROM vertices_ways_car As n
  ORDER BY f.geom <-> n.the_geom LIMIT 1
)as closest_node
from facilities f
````
Creamos índices sobre las dos columnas:

````sql
CREATE INDEX nodes_facilities_node_idx ON nodes_facilities (closest_node);
CREATE INDEX nodes_facilities_facility_idx ON nodes_facilities (facility);
````

Una vez que tenemos la relación entre nodos y facilities en una tabla, podemos usar la función `pgr_drivingDistance` para calcular las áreas alrededor de todos los nodos. Si vamos a la [documentación](http://docs.pgrouting.org/2.2/en/src/driving_distance/doc/pgr_drivingDistance.html#pgr-drivingdistance), podemos ver que la función admite, además de un solo id, un *Array* de ids para los nodos origen. Un *Array* es un tipo de datos de Postgres que agrupa varios elementos del mismo tipo:

````sql
select array(select closest_node from nodes_facilities limit 10)
````
Como ven, el resultado de esta consulta es jústamente lo que necesitamos para la versión múltiple de `pgr_drivingDistance`:
````
array
[17359L, 87494L, 64874L, 213808L, 213808L, 213808L, 46291L, 124321L, 100647L, 70326L]
````
Entonces, podemos simplemente pasar la consulta anterior como argumento a la función:

````sql
SELECT * FROM pgr_drivingDistance(
      'SELECT gid as id, source, target,
       (st_length(the_geom::geography)/1000)/velocidad_pico as cost,
       (st_length(the_geom::geography)/1000)/velocidad_pico_reversa as reverse_cost
       FROM ways_car',
      (select array(select closest_node from nodes_facilities)), 0.16
    );
````

Los paréntesis alrededor de la consulta que regresa el array son para indicarle al intérprete que tiene que evaluar eso antes que lo demás.

Como pueden ver, el resultado es una tabla con todos los puntos que quedan a menos de 0.16 horas de cada nodo de entrada. Entonces, agrupando por nodos (columna `from_v` en el resultado), obtendremos los puntos que necesitamos para construir cada polígono (area de servicio).

En la sección anterior utilizamos `pgr_pointsAsPolygon` para encontrar la envolvente cóncava de los puntos, si bien es cierto que esa aproximación resulta en polígonos que representan mejor el área de servicio, la consulta para obtener los polígonos de esta forma es sumamente compleja, entonces, por simplicidad, vamos a utilizar la envolvente convexa. Lo primero que vamos a hacer es guardar el resultado en una tabla:

````sql
create table temp as
select * from vertices_ways_car v,
(SELECT node, from_v FROM pgr_drivingDistance(
        'SELECT gid as id, source, target,
         (st_length(the_geom::geography)/1000)/velocidad_pico as cost,
         (st_length(the_geom::geography)/1000)/velocidad_pico_reversa as reverse_cost
         FROM ways_car',
        (select array(select closest_node from nodes_facilities)), 0.16
      )) as service
where v.id = service.node
````

Ahora sí, agrupamos sobre la columna `from_v`, colectamos las geometrías y calculamos la envolvente:

````sql
select  from_v, st_convexHull(ST_collect(the_geom)) as geom
from temp
group by from_v
having count(from_v) > 2
````

La cláusula `having count(from_v) > 2` nos asegura que siempre estemos pasando más de dos puntos a la función que calcula la envolvente convexa (es decir, estamos tratando de asegurarnos de que la envolvente sea realmente un polígono).
