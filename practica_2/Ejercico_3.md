Ejercicio 3: intersecciones etiquetadas
=======================================

En este ejercicio vamos a etiquetar las intersecciones de grupos de polígonos, para hacerlo vamos a utilizar los conceptos de unión y de primitivos espaciales que desarrollamos en el ejercicio 1.


En la carpeta data de esta práctica hay un shape que se llama poligonos_intersecciones, súbelo a la base de datos (está en proyección 32614). Asumiremos que está en el esquema practica_2 y que la tabla se llama poligonos_intersecciones.

Primero, vamos a checar el tipo de geometría que tiene la tabla:

```sql
select st_astext(geom)
from practica_2.poligonos_intersecciones
```

Son tipo `MULTIPOLYGON`, pero en realidad nosotros sabemos que son poligonos simples (cuenta las filas de la tabla), entonces transformémolos para simplificar el proceso:

```sql
alter table practica_2.poligonos_intersecciones
alter column geom type geometry(Polygon,32614)
using st_geometryN(geom,1);
```

Ahora vamos a crear dos colecciones de polígonos usando el atributo colection de la tabla de polígonos:

```sql
create table colecciones as
select colection, st_collect(geom)
from poligonos_intersecciones
group by colection
```

Esta es la tabla que es la base para el ejercicio: tenemos dos colecciones de polígonos (¿Qué tipo de geometría es?) y necesitamos etiquetar las intersecciones de acuerdo a la colección y al polígono individual.

Creemos una tabla con los anillos exteriores de los polígonos:

```sql
create table anillos_poligonos as
select colection,st_exteriorring(geom) as geom
from poligonos_intersecciones;
```

Visualiza la tabla en QGis y checa que sólo nos quedamos con la frontera de los polígonos. ¿Cuántas fronteras tenemos?

Ahora vamos a asegurarnos de tener nodos en todas las intersecciones (recuerden lo que hace `ST_Union`):

```sql
create table practica_2.segmentos_anillos as
select ST_GeometryN(foo.geom,generate_series(1,ST_NumGeometries(foo.geom))) as geom
from(
select st_union(geom) as geom
from practica_2.anillos_poligonos
) as foo;

alter table practica_2.segmentos_anillos add column gid serial;
```

Si ven la tabla en Qgis, van a notar que tenemos nodos en todas las intersecciones y que, debido al proceso de digitalización, conservamos algunos nodos internos.

Algo importante de notar es que perdimos la información de los atributos (colection), piénsenlo, no tenemos forma de asignarlos a estos segmentos.
No importa, al rato los regresamos.

Ahora vamos a utilizar `ST_Polygonize(geom)` para generar todos los polígonos posibles a partir de los segmentos.
Polygonize regresa un __GEOMETRYCOLLECTION__ con todos los polígonos:

```sql
select st_astext(st_polygonize(geom)) from practica_2.segmentos_anillos;
```

Entonces hay que desbaratar el resultado con ST_Dump(GEOMETRYCOLLECTION) para obtener cada polígono:

```sql
select st_dump(st_polygonize(geom)) from practica_2.segmentos_anillos;
```
Como pueden ver ST_Dump regresa una cosa extraña: ({n},geom). Se llama un `geometry_dump` y es un tipo compuesto, es decir, una columna con dos campos (en este caso los campos son path, el número de la geometría, y la geometría misma, para más detalles, chequen las documentaciones de ST_Dump() y geometry_dump). Accedemos a la geometría del `geometry_dump` utilizando la notación punto, como si fuera una fila de una tabla:

```sql
select st_astext((st_dump(st_polygonize(geom))).geom) from practica_2.segmentos_anillos;
```

Ahora podemos crear una tabla con todos los polígonos generados por `st_polygonize`:

```sql
create table practica_2.intersecciones as
select  (st_dump(st_polygonize(geom))).geom from practica_2.segmentos_anillos;

alter table practica_2.intersecciones add column gid serial;
```


--Ahora lo único que falta es etiquetar a los polígonos de acuerdo a los polígonos originales. Para eso, primero pasémoslos a puntos utilizando ST_Centroid():

Como pueden ver, ya tenemos todas las intersecciones, ahora lo único que hace falta es etiquetarlas, para eso, utilicemos los centroides:

```sql
select gid, st_centroid(geom) as geom from practica_2.intersecciones
```

Vamos a utilizar estos puntos para hacer una unión espacial con la capa original y creamos el atributo que etiqueta a los polígonos:

```sql
select po.colection || po.element as etiqueta, cen.gid
from (select gid, st_centroid(geom) as geom from intersecciones) as cen
join poligonos_intersecciones po
on st_intersects(po.geom,cen.geom)
```


Vean que en el resultado ya casi tenemos lo que buscábamos, cada punto (cada gid), tiene asignados los atributos de los polígonos originales, sólo que  los puntos que tocan a más de uno de los polígonos originales vienen repetidos. Para construir la tabla final con las intersecciones etiquetadas, vamos a unir los atributos de los puntos a la capa de intersecciones y luego a agrupar el resultado por el identificador de centroide y concatenar las etiquetas:


```sql
create table intersecciones_etiquetadas as
select s.inter_id as gid , string_agg(s.etiqueta, '.') as etiqueta ,  min(s.geom) as geom
from(
select foo.etiqueta,foo.gid as inter_id, inter.geom from intersecciones inter
join
(select po.colection || po.element as etiqueta, cen.gid
    from (select gid, st_centroid(geom) as geom from intersecciones) as cen
    join poligonos_intersecciones po
    on st_intersects(po.geom,cen.geom)) as foo
on foo.gid=inter.gid
) as s
group by s.inter_id
 ```

Fíjense como usamos el `min(geom)` porque sabemos que todas las geometrías agrupadas son iguales!
