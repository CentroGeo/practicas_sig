--En la carpeta data de esta práctica hay un shape que se llama poligonos_intersecciones, súbelo a la base de datos
--(está en proyección 32614). Asumiremos que está en el esquema practica_2 y que la tabla se llama poligonos_intersecciones.

--El primer paso es crear dos colecciones de polígonos a través del atributo collection (busca en la documentación la función st_collect(geom)):

select collection, st_astext(st_collect(geom))
from practica_2.poligonos_intersecciones  
group by collection;

--Como puedes ver, st_collect regrersa una geometrycollection, esto se debe a que el tipo de geometría es multipolygon:

select st_astext(geom)
from practica_2.poligonos_intersecciones

--Pero en realidad, nuestros polígonos no son multi, son sensillitos, entonces convirtamoslos a single part:

alter table practica_2.poligonos_intersecciones 
alter column geom type geometry(Polygon,32614)
using st_geometryN(geom,1);

--Ahora sí los polígonos son ya "single part" (chécalo), agreguemoslos colectados en una nueva tabla:

create table practica_2.poligonos_colectados as
select min(gid) as gid,collection, st_collect(geom) as geom
from practica_2.poligonos_intersecciones  
group by collection;

ALTER TABLE practica_2.poligonos_colectados ALTER COLUMN "gid" SET NOT NULL;
ALTER TABLE practica_2.poligonos_colectados ADD UNIQUE ("gid");
ALTER TABLE practica_2.poligonos_colectados ADD PRIMARY KEY ("gid");

---TENGO que checar bien, pero aquí está el camino:
select row_number() OVER () as rnum, st_union(st_exteriorring(geom)) as geom 
from practica_2.poligonos_intersecciones  
group by collection; 



create table practica_2.poligonos_lineas as
select collection,element,st_exteriorring(geom) as geom 
from practica_2.poligonos_intersecciones;

drop table practica_2.muchas_lineas

create table practica_2.muchas_lineas as 
select ST_GeometryN(foo.geom,generate_series(1,ST_NumGeometries(foo.geom))) as geom
from(
select st_astext(st_union(geom)) as geom 
from practica_2.poligonos_lineas lineas
) as foo

alter table practica_2.muchas_lineas add column gid serial

create table practica_2.intersecciones as 
select (st_dump(st_polygonize(geom))).path[1], (st_dump(st_polygonize(geom))).geom from practica_2.muchas_lineas;

