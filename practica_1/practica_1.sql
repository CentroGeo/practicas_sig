--El primer paso es proyectar las geometrías de las manzanas para que sean compatibles con las estaciones del metro y el límite metropolitano
-- Es mejor proyectar las manzanas para que todo está en coordenadas planas, de ese modo los cálculos geométricos son mucho más rápidos

 ALTER TABLE manzanas_zmvm 
   ALTER COLUMN geom 
   TYPE Geometry(Polygon, 32614) 
   USING ST_Transform(geom, 32614);

--Ahora vamos a cortar las manzanas con el polígono del límite metropolitano (lo que se llama un clip, pues) y meter el resultado en la tabla manzanas_zmvm:
select manzanas.* into manzanas_zmvm from manzanas 
inner join limite_metropolitano on
st_intersects(limite_metropolitano.geom,manzanas.geom);
--Nota como lo que hicimos fue en realidad un inner join pero como condición utilizamos una relación espacial: st_intersects

--creamos un índice espacial sobre la geometría
create index manzanas_zmvm_gix on manzanas_zmvm using GIST(geom);

--vemos si los gid son únicos
select count(*) from manzanas_zmvm  group by gid order by count(*) desc;

--como la tabla tiene unos gid's repetidos, alteramos la columna para que sean únicos
CREATE SEQUENCE "manzanas_zmvm_gid_seq";
update manzanas_zmvm set gid = nextval('"manzanas_zmvm_gid_seq"');

--Creamos los constraints necesarios y agregamos un PK
ALTER TABLE manzanas_zmvm ALTER COLUMN "gid" SET NOT NULL;
ALTER TABLE manzanas_zmvm ADD UNIQUE ("gid");
ALTER TABLE manzanas_zmvm ADD PRIMARY KEY ("gid");


--Ahora podemos empezar a hacer algunas preguntas interesantes, por ejemplo:
--¿cuantas manzanas quedan a 500 metros de cada estación del metro?
select foo.* from
(with buf as (select st_buffer(estaciones_metro.geom,500.0) as geom , estaciones_metro.nombreesta as estacion from estaciones_metro)
select count(manzanas_zmvm.gid), buf.estacion from manzanas_zmvm join buf on 
st_intersects(buf.geom,manzanas_zmvm.geom)
group by buf.estacion) as foo;

--Tambien podemos preguntar ¿Cuánta gente vive a 500 m de una estación del metro?
--Nota: La columna pob1 contiene la población de cada manzana
select foo.* from
(with buf as (select st_buffer(estaciones_metro.geom,500.0) as geom , estaciones_metro.nombreesta as estacion from estaciones_metro)
select sum(manzanas_zmvm.pob1), buf.estacion from manzanas_zmvm join buf on 
st_intersects(buf.geom,manzanas_zmvm.geom)
group by buf.estacion) as foo;