--El primer paso es crear una linea a partir de los puntos de la tabla waypoints. La linea que creemos dependerá del orden en el que juntemos los puntos,
--entonces, ordenémoslos por id:
--La cláusula GROUP BY track_id, agrupa los puntos de acuerdo a un identificador de recorrido, 
--en el caso de que tuvieramos más de uno. (Guarda nota de esto porque será importante en los ejercicios)

CREATE TABLE practica_2.gps_tracks AS
SELECT
ST_MakeLine(geom) AS geom,
track_id
FROM (
SELECT * FROM practica_2.waypoints
ORDER BY id
) AS ordered_points
GROUP BY track_id;

--¿Que tipo de geometría generamos al unir los puntos? Veamos:
SELECT ST_asText(geom) from practica_2.gps_tracks;

-- Si visualizas la capa en QGis, notarás que la linea que construimos contiene una auto-intersección y que no está cerrada
-- (el primero y el último punto no coinciden)
-- Para resolver este problema, vamos a generar un nodo en la auto-intersección:
--[Pregunta # 1: ¿Qué hace el operador ST_UnaryUnion() y, más en general, ¿Qué hace una unión en Postgis?]

UPDATE practica_2.gps_tracks
SET geom = ST_UnaryUnion(geom)

-- Para ver el resultado de la operación anterior, vamos a desbaratar la linea que creamos en sus componentes:

SELECT  ST_asText(ST_GeometryN(geom,generate_series(1,ST_NumGeometries(geom)))) AS lines
FROM practica_2.gps_tracks

--Esto nos regresa un conjunto de objetos tipo Linestring (véanlo). 
--Aquí utilizamos dos funciones nuevas; ST_GeometryN() y ST_NumGeometries(), consulta la documentación de Postgis para
--entender su significado.

--Ahora que hemos separado el Multilinestring en sus componentes, vamos a desarmar éstas líneas en sus 
--componentes básicos:

SELECT ST_AsText(
   ST_PointN(
	  lines,
	  generate_series(1, ST_NPoints(lines))
   ))
FROM (
	SELECT 
		ST_GeometryN(geom,
	generate_series(1,ST_NumGeometries(geom))) AS lines
	FROM practica_2.gps_tracks
) AS foo;

--Nota que hicimos las dos consultas anidadas, es decir, primero hacemos la consulta anterior y luego la envolvemos 
--con la consulta que nos regresa los puntos.
--Ahora, para poder visualizar el resultado en QGis, necesitamos agregar un id a los puntos y ponerlos en una tabla:

CREATE TABLE practica_2.waypoints_nuevos AS
SELECT 
   ST_PointN(
	  lines,
	  generate_series(1, ST_NPoints(lines))
   ) as geom
FROM (
	SELECT 
		ST_GeometryN(geom,
	generate_series(1,ST_NumGeometries(geom))) AS lines
	FROM practica_2.gps_tracks
) AS foo;

alter table practica_2.waypoints_nuevos add column gid serial;

--Como podemos ver, creamos un punto el la auto-intersección. Ahora regresemos a la tabla gps_tracks y creemos un polígono:
CREATE TABLE gps_lakes AS
SELECT
ST_BuildArea(the_geom) AS lake,
track_id
FROM gps_tracks;

--Ahora pueden visualizar el lago en QGis. PREGUNTA #2: ¿Qué hubiera pasado si no ponemos un nodo en la auto-intersección?
--Hint: ver en la documentación--> ¿Qué es un polígono?

--EJERCICIO # 1: Con los puntos de las estaciones del metro de la práctica anterior, crea las líneas del metro.
--Hint: Para crear todas las líneas tienes que agrupar los puntos

