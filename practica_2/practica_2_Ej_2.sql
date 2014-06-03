-- Aquí vamos a seguir un rato el tutorial de Boundless. La idea es entender el modelo DE9IM para relaciones espaciales
-- y además aprender a ingresar geometrías a mano, sin pasar por shapes.

--En este ejemplo vamos a trabajar con geometrías sin proyección, todo estará en coordenadas locales
--Nota: como vamos a crear objetos del tipo geometría, estos serán planos (proyectados aun cuando no especifiquemos la pryección)
--PREGUNTA #1: ¿Cual es la diferencia entre los tipos Geometry y Geography en PostGis?
--Primero vamos a crear un par de tablas para guardar los datos con los que vamos a probar:

CREATE TABLE practica_2.lineas (id serial primary key, geom geometry);
CREATE TABLE practica_2.poligonos ( id serial primary key, geom geometry );

--Ahora vamos a usar la función ST_Relate(geom,geom) para obtener la matriz de relaciones de las geometrías.
SELECT st_relate(practica_2.lineas.geom,practica_2.poligonos.geom)
FROM practica_2.lineas,practica_2.poligonos;

--PREGUNTA #2: Escribe en un párrafo la interpretación de la matriz de relaciones

--Ahora vamos a borrar los datos de las tablas que creamos:
delete from practica_2.lineas;
delete from practica_2.poligonos;

--Ahora vamos a subir en las mismas tablas los datos necesarios para seguir con el ejercicio del tutorial:

INSERT INTO practica_2.poligonos ( geom )
  VALUES ( 'POLYGON ((100 200, 140 230, 180 310, 280 310, 390 270, 400 210, 320 140, 215 141, 150 170, 100 200))');
  
INSERT INTO practica_2.lineas (geom)
  VALUES
        ('LINESTRING (170 290, 205 272)'),
        ('LINESTRING (120 215, 176 197)'),
        ('LINESTRING (290 260, 340 250)'),
        ('LINESTRING (350 300, 400 320)'),
        ('LINESTRING (370 230, 420 240)'),
        ('LINESTRING (370 180, 390 160)');
        
--Ahora, las líneas 'buenas' son aquellas con las siguientes características:
--a) Su interior tiene una intersección de dimensión 1 (linea) con el interior del polígono
--b) Sus fronteras tienen una intersección de dimensión 0 (punto) con el interior del lago
--c) Sus fronteras tienen una intersección de dimensión 0 (punto) con la frontera del lago
--d) Sus interiores no se intersectan con el exterior del lago
-- Entonces, el patrón que estamos buscando para su matriz de intersecciones es '1FF00F212' (¿Por qué?)
--Encontremos las líneas 'buenas':

SELECT practica_2.lineas.*
FROM practica_2.lineas JOIN practica_2.poligonos ON ST_Intersects(practica_2.lineas.geom, practica_2.poligonos.geom)
WHERE ST_Relate(practica_2.lineas.geom, practica_2.poligonos.geom, '1FF00F212');

-- El ejercicio final de ésta práctica consiste en extraer, a partir de las líneas de metro que creamos, las estaciones de conexión
-- y las estaciones terminales de cada linea. Para esto, el único operador nuevo que necesitan es st_crosses(geom1,geom2) que
-- nos dice si una geometría 'atraviesa' a otra.

--Para ilustrar esto regresemos a las tablas de líneas y polígonos que usamos en este ejercicio. 
-- Vamos a preguntar si la linea con id=4 crusa el polígono:
select st_crosses(practica_2.lineas.geom,practica_2.poligonos.geom)
from practica_2.lineas, practica_2.poligonos
where practica_2.lineas.id =4 and practica_2.poligonos.id =1;
--El resultado es False, no la cruza. Ahora cambiemos la linea por la de id 5, esa si la cruza.
-- ¿Qué pasa si utilizamos la línea con id 1, que toca al polígono?