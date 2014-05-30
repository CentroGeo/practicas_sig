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
create index calles_zmvm_gix on calles_zmvm using GIST(geom);

--vemos si los gid son únicos
select count(*) from calles_zmvm  group by gid order by count(*) desc;

--como la tabla tiene unos gid's repetidos, alteramos la columna para que sean únicos
CREATE SEQUENCE "calles_zmvm_gid_seq";
update calles_zmvm set gid = nextval('"calles_zmvm_gid_seq"');

--Creamos los constraints necesarios y agregamos un PK
ALTER TABLE calles_zmvm ALTER COLUMN "gid" SET NOT NULL;
ALTER TABLE calles_zmvm ADD UNIQUE ("gid");
ALTER TABLE calles_zmvm ADD PRIMARY KEY ("gid");


--Ahora podemos empezar a hacer algunas preguntas interesantes, por ejemplo:
--¿cuantas manzanas quedan a 500 metros de cada estación del metro?
(with buf as (select st_buffer(estaciones_metro.geom,500.0) as geom , estaciones.nombre as estacion from estaciones)
select count(manzanas_zmvm.gid), buf.estacion from manzanas_zmvm join buf on 
st_intersects(buf.geom,manzanas_zmvm.geom)
group by buf.estacion) as foo;