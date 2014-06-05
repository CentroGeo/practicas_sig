--En la carpeta data de esta práctica hay un shape que se llama poligonos_intersecciones, súbelo a la base de datos
--(está en proyección 32614). Asumiremos que está en el esquema practica_2 y que la tabla se llama poligonos_intersecciones.


--Primero, vamos a checar el tipo de geometría que tiene la tabla:

select st_astext(geom)
from practica_2.poligonos_intersecciones

--Son tipo MULTIPOLYGON, pero en realidad nosotros sabemos que son poligonos simples (single part), entonces transformémolos para simplificar el proceso:

alter table practica_2.poligonos_intersecciones 
alter column geom type geometry(Polygon,32614)
using st_geometryN(geom,1);

--Ahora sí los polígonos son ya "single part" (chécalo), agreguemoslos colectados en una nueva tabla:


--Primero vamos a crear una tabla con los anillos exteriores de los polígonos:

create table practica_2.anillos_poligonos as
select collection,element,st_exteriorring(geom) as geom 
from practica_2.poligonos_intersecciones;
--Visualiza la tabla en QGis y checa que sólo nos quedamos con la frontera de los polígonos.

--Ahora vamos a asegurarnos de tener puntos en todas las intersecciones (ver la documentación de ST_Union(geom):

create table practica_2.segmentos_anillos as 
select ST_GeometryN(foo.geom,generate_series(1,ST_NumGeometries(foo.geom))) as geom
from(
select st_union(geom) as geom 
from practica_2.anillos_poligonos
) as foo

 -- Le agregamos una columna serial para poder visualizarla en QGis:
alter table practica_2.segmentos_anillos add column gid serial
-- Chequen que los anillos están segmentados.
-- Algo importante de notar es que perdimos la información de los atributos (collection y element), piénsenlo, no tenemos forma de asignarlos a estos segmentos.
-- No importa, al rato los regresamos.

--Ahora vamos a utilizar st_Polygonize(geom) para generar todos los polígonos posibles a partir de los segmentos.
--Polygonize regresa un GEOMETRYCOLLECTION con todos los polígonos:

select st_astext(st_polygonize(geom)) from practica_2.segmentos_anillos;
--Entonces hay que desbaratar el resultado con ST_Dump(GEOMETRYCOLLECTION) para obtener cada polígono:
select st_dump(st_polygonize(geom)) from practica_2.segmentos_anillos;
--Como pueden ver ST_Dump regresa una cosa extraña: ({n},geom)
--Se llama un geometry_dump y es un tipo compuesto, es decir, un conjunto de nombres de campo y sus tipos de datos 
--(en este caso los campos son path y geom, para más detalles, chequen las documentaciones de ST_Dump() y geometry_dump).
-- Accedemos a la geometría del geometry_dump utilizando la notación punto, como si fuera una fila de una tabla:
select st_astext((st_dump(st_polygonize(geom))).geom) from practica_2.segmentos_anillos;

--Ahora podemos crear una tabla con todos los polígonos generados por poligonize
create table practica_2.intersecciones as 
select  (st_dump(st_polygonize(geom))).geom from practica_2.segmentos_anillos;
 --Y otra vez le agregamos un id para visualizarla:
alter table practica_2.intersecciones add column gid serial
 --Visualicen el resultado en QGis
 
 --Ahora lo único que falta es etiquetar a los polígonos de acuerdo a los polígonos originales. Para eso, primero pasémoslos a puntos utilizando ST_Centroid():
create table practica_2.centroides as 
select gid, st_centroid(geom) as geom from practica_2.intersecciones

--Hacemos una unión espacial de los centroides con los polígonos originales para asignarle a los primeros los atributos de los segundos:
--(Noten el operador de concatenar ||)
 select po.collection || po.element as etiqueta, cen.gid from practica_2.centroides cen
 join practica_2.poligonos_intersecciones po 
 on st_intersects(po.geom,cen.geom)
 
 --Vean que en el resultado ya tenemos lo que buscábamos, cada punto (cada gid), tiene asignados los atributos de los polígonos originales.
 --Ahora sólo pegemos todo una tabla para visualizarlo en QGis:
 
create table practica_2.intersecciones_etiquetadas as 
select foo.etiqueta,inter.geom from practica_2.intersecciones inter
join 
(select po.collection || po.element as etiqueta, cen.gid from practica_2.centroides cen
 join practica_2.poligonos_intersecciones po 
 on st_intersects(po.geom,cen.geom)) as foo 
 on foo.gid=inter.gid

