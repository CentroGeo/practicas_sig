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


# Segundo ejercicio: Trabajando con redes más reales

En esta parte de la práctica, vamos a utilizar una red de calles extraida de [OpenStreetMap](https://www.openstreetmap.org/), estos son datos contribuidos por usuarios, una especie de wikipedia para cartografía digital. Una ventaja de OSM es que desde un principio fue pensado como una fuente de datos para calcular rutas, de modo que su estructura permite construir una red topológica de manera natural (por suspuesto, tiene la desventaja de ser [VGI](https://en.wikipedia.org/wiki/Volunteered_geographic_information), lo que nos puede hacer dudar de su precisión, validez, etc.).

El proceso para importar la red de OSM a postgres es demasiado largo como para hacerlo en el taller, entonces trabajaremos a partir de un respaldo de una base preparada con anticipación. De cualquier modo, si te interesa saber cómo utilizar los datos de OSM en pgrouting, el proceso involucra dos etapas:

1. Obtener los datos de la zona de interés, directamente de la página de [OSM](https://www.openstreetmap.org/) o bien de algún servicio de agregación como los extractos metropolitanos de [Mapzen](https://mapzen.com/data/metro-extracts)
2. Importar los datos a postgres y crear la topología. Para esto puedes utilizar [osm2pgrouting](http://pgrouting.org/docs/tools/osm2pgrouting.html) (que es libre, aunque hay que compilarlo y puede resultar algo complicado) o [osm2po](http://osm2po.de/) (que no es libre pero es gratuito)

Para importar los datos de esta práctica necesitas crear una nueva base de datos, digamos, `red_osm`. No es necesario que le agregues las extensiones de PostGis y pgrouting, el respaldo ya las incluye (claro, sólo si están ya instaladas en el servidor). Una vez que hayas creado la base de datos puedes, desde pgAdmin, dar botón derecho y seleccionar la opción "Restaurar", navega hasta el archivo `osm_mex.backup` y selecciónalo. Listo! tenemos una base de datos lista para trabajar.

La base de datos que acabamos de crear tiene las siguientes tablas:

````
Schema |           Name           |   Type   | Owner
--------+--------------------------+----------+-------
public | classes                  | table    | user
public | nodes                    | table    | user
public | relation_ways            | table    | user
public | relations                | table    | user
public | types                    | table    | user
public | way_tag                  | table    | user
public | ways                     | table    | user
public | ways_car                 | table    | user
public | ways_vertices_pgr        | table    | user

````
las tablas `ways` y `ways_vertices_pgr` son las que contienen los segmentos y los nodos respectivamente. Dentro de la tabla `ways` vas a encontrar las columnas `source` y `target` cuyo significado ya debes de conocer bien. Además puedes notar que hay una columna llamada `r_cost`, esta representa el costo de recorrer la calle en sentido contrario (sí, esta red tiene los sentidos de la calle bien hechos!). La columna `to_cost`, que viene vacía sirve para que nosotros almacenemos un costo por defecto para la red.  

Ahora bien, la red que importamos desde OSM contiene segmentos que no corresponden a calles (ríos, canales, etc.) o bien segmentos por donde no pueden circular automóviles, entonces, para el primer ejercicio vamos a utilizar la tabla `ways_car` que es un extracto de `ways` que contiene sólo los segmentos que corresponden a calles por donde pueden circular automóviles.

Para ir agarrando familiaridad con la red, calculemos una ruta usando los algoritmos que ya conocemos:

### Dijkstra:

````sql
select c.gid, c.the_geom from ways_car c,
 (SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         st_length(the_geom)::double precision AS cost,
                         reverse_cost::double precision AS reverse_cost
                        FROM ways_car',
                36198, 2064, false, true)) as ruta
where c.gid = ruta.edge
````

### A*:

````sql
select c.gid, c.the_geom from ways_car c,
 (SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_astar('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         st_length(the_geom)::double precision AS cost,
                         reverse_cost::double precision AS reverse_cost,
                         x1, y1, x2, y2
                        FROM ways_car',
                36198, 2064, false, true)) as ruta
where c.gid = ruta.edge
````

Como puedes ver, hay dos diferencias con lo que hicimos el ejercicio anterior:

1. En lugar de pasarle una columna como costo, estamos pasando un query como costo (`st_length(the_geom)::double precision AS cost`), esta es una de las grandes ventajas de pgrouting, podemos usar cualquier cosa como costo sin necesidad de recalcular la red (toma eso NetworkAnalyst).

2. Estamos usando la columna  `reverse_cost` para indicarle al algoritmo cuál es el costo de recorrer el segmento en sentido opuesto. En caso de que la vía sea de un sólo sentido, el costo en reversa es muy alto (usualmente el coso multiplicado por 1000000), para impedir que el algoritmo lo seleccione.

Ahora, vamos a utilizar como costo el tiempo de recorrido asumiendo una velocidad constante para cada tipo de via. Por ejemplo, utilicemos la velocidad máxima para cada segmento como base para calcular el tiempo de recorrido:

````sql
select (st_length(the_geom::geography)/1000)/maxspeed_forward as tiempo from ways_car limit 100
````
Nota: cuando hacemos `st_length(the_geom::geography)` estamos calculando la distancia del segmento sobre el esferoide.

Con la consulta anterior tenemos el tiempo de recorrido (en horas) para cada segmento, ahora, esto lo podemos usar directamente como costo en el algoritmo de ruta:

````sql
select c.gid, c.the_geom from ways_car c,
 (SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_astar('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         (st_length(the_geom::geography)/1000)/maxspeed_forward::double precision AS cost,
                         reverse_cost::double precision AS reverse_cost,
                         x1, y1, x2, y2
                        FROM ways_car',
                36198, 2064, false, true)) as ruta
where c.gid = ruta.edge
````
### Pregunta:
¿Cuánto tiempo tardamos en llegar?


Como pueden ver, la ruta en este caso es igual con ambos costos. Compliquemos las cosas un poco, supongamos que estamos en hora pico y que las velocidades se ven modificadas de la siguiente forma:

* Vialidades primarias: una octava parte del máximo
* Vialidades secundarias: una cuarta parte del máximo
* Vialidades menores: la mitad del máximo

Primero vamos a calcular la nueva velocidad máxima para cada tipo de segmento:

````sql
select class_id,
   case when class_id in(101,102,103) then maxspeed_forward/8
   when class_id in(106,107,108) then maxspeed_forward/4
   else maxspeed_forward/2
   end
from ways_car
````
Para simplificar las consultas siguientes, vamos a poner estos valores en una nueva columna:

````sql
alter table ways_car add column velocidad_pico float;
update ways_car set velocidad_pico =
    case when class_id in(101,102,103) then maxspeed_forward/8
    when class_id in(106,107,108) then maxspeed_forward/4
    else maxspeed_forward/2
end;
````

Ahora sí, vamos a calcular la ruta usando las nuevas velocidades (lo único que necesitamos cambiar es la velocidad que vamos a usar):

````sql
select c.gid, c.the_geom from ways_car c,
 (SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_astar('
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         (st_length(the_geom::geography)/1000)/velocidad_pico::double precision AS cost,
                         reverse_cost::double precision AS reverse_cost,
                         x1, y1, x2, y2
                        FROM ways_car',
                36198, 2064, false, true)) as ruta
where c.gid = ruta.edge
````
Comparen las dos rutas y los tiempos de traslado en cada caso.

## Problema del Agente Viajero

Ahora vamos a usar pgrouting para resolver el problema de encontrar el camino óptimo para un repartidor que tiene que visitar varias localizaciones en su ruta y regresar al lugar de origen. Matemáticamente, el problema consiste en encontrar un [ciclo hamiltoniano](https://en.wikipedia.org/wiki/Hamiltonian_path) mínimo en una gráfica dirigida y con pesos.

El primer paso es definir cuales son los lugares por donde debe pasar el agente, para esto vamos a seleccionar un conjunto de nodos de la red que servirán como los _puntos de reparto_ y un nodo que será la _base_ del repartidor.

Para resolver el problema vamos a utilizar el algoritmo [pgr_tsp](http://docs.pgrouting.org/dev/src/tsp/doc/index.html) de pgrouting. Este algoritmo es bastante más complejo y funciona un poco diferente que los que hemos usado, en lugar de regrasarte la ruta entre todos los puntos, regresa el orden en el que estos deben ser visitados de acuerdo a su distancia euclidiana o a una matriz de distancia que nosotros definamos. Idealmente, la matriz de distancia la podríamos construir tomando todas las distancias entre nuestros nodos de interes, calculadas usando Dijkstra, por ejemplo. Sin embargo, para simplificar el problema, vamos a utilizar la versión más simple del algoritmo. De la documentación podemos ver que lo que necesitamos para correr el algoritmo es:


* sql: Una consulta que regrese las siguientes columnas:
  * id:	int4 identificador del vértice
  * x:	float8 coordenada x
  * y:	float8 coordenada y

* start_id:	int4 id del punto de inicio
* end_id:	int4 id del punto final, esta opción es opcional, si es onitida se asume el nodo final es el mismo que el inicial

Entonces, nuestra consulta queda de la siguiente manera:

````sql
SELECT seq, id1, id2, round(cost::numeric, 2) AS cost
	   FROM pgr_tsp('select id::int, st_x(the_geom) as x, st_y(the_geom) as y FROM ways_vertices_pgr
	where id in (36104,2099,26248,25170)', 36104, 25170)
````

Al ejecutar la consulta, lo que nos regresa es una tabla con la secuencia en la que tenemos que recorrer los nodos y el costo _estimado_ en cada segmento del recorrido. Ahora visualicemos la secuencia:

````sql
select p.id, orden.seq, p.the_geom
from
	(SELECT seq, id1, id2, round(cost::numeric, 2) AS cost
	   FROM pgr_tsp('select id::int, st_x(the_geom) as x, st_y(the_geom) as y FROM ways_vertices_pgr
	where id in (36104,2099,26248,25170)', 36104, 25170)) as orden
join ways_vertices_pgr p
on p.id = orden.id2
````

### Ejercicio final:

Como pueden ver, el algoritmo no nos regresa la ruta que debemos seguir, sin embargo es posible obtenerla usando alguno de los algoritmos de ruteo que conocemos. El ejercicio es obtener la ruta completa del circuito y dibujarla en QGIS.
