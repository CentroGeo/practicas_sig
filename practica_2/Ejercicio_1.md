Primitivos espaciales; armando y desarmando.
=============

En este primer ejercicio vamos a estudiar la forma en la que se construye la estructura jerárquica de los objetos geométricos en una base de datos.

Para esta práctica utilizaremos las capas de datos que puedes encontrar en la carpeta `practica_2/data/` de este repositorio.
Recuerda que antes de comenzar debes subir todos los _shapes_ de dicha carpeta a tablas en Postgis, para efectos del resto del instructivo, asumiremos que subiste las capas en una base de datos llamada practicas_sig y en el esquema practica_2, como se ve en el siguiente diagrama:

	+practicas_sig
		+practica_1
			+tablas...
		+practica_2
			+tablas...

Ejercicio
=============

En este ejercicio vamos a construir un polígono a partir de una serie de puntos (tomados con un GPS).

El primer paso es crear una linea a partir de los puntos de la tabla waypoints. La linea que creemos dependerá del orden en el que juntemos los puntos,
entonces, ordenémoslos por id (este es el orden en el que fueron tomados por el gps):

La cláusula GROUP BY track_id, agrupa los puntos de acuerdo a un identificador de recorrido,
en el caso de que tuvieramos más de uno. (Guarda nota de esto porque será importante en los ejercicios)

 ``` sql
	CREATE TABLE practica_2.gps_tracks AS
	SELECT
	ST_MakeLine(geom) AS geom,
	track_id
	FROM (
	SELECT * FROM practica_2.waypoints
	ORDER BY id
	) AS ordered_points
	GROUP BY track_id;
```
¿Que tipo de geometría generamos al unir los puntos? Veamos:

``` sql
	SELECT ST_asText(geom) from practica_2.gps_tracks;
```
Si visualizas la capa en QGis, notarás que la linea que construimos contiene una auto-intersección y que no está cerrada (el primero y el último punto no coinciden), para construir un polígono necesitamos cerrar un anillo. Para resolver este problema, vamos a generar un nodo en la auto-intersección:
``` sql
	UPDATE practica_2.gps_tracks
	SET geom = ST_UnaryUnion(geom)
```
El operador espacial `ST_Union()` regresa la unión del conjunto de puntos de una collección de geometrías (`ST_UnaryUnion()` es una extensión para unir una geometría consigo misma). En otras palabras, la unión en PostGis regresa un conjunto de geometrías sólo se tocan en puntos (compara este concepto de unión con la unión geométrica en Arc). Veamos qué tipo de geometría tenemos ahora:

``` sql
	SELECT ST_asText(geom) from practica_2.gps_tracks;
```
Para entender lo que nos regresó la unión, vamos a desbaratar la colección en sus componentes:

``` sql
	SELECT  generate_series(1,ST_NumGeometries(geom)) as id,
	ST_asText(ST_GeometryN(geom,generate_series(1,ST_NumGeometries(geom)))) AS lines
	FROM practica_2.gps_tracks
```

Visualicen la capa en Qgis y coloreen por el id de linea. Como pueden ver, ahora tenemos 3 líneas, una que se cierra y dos que sobran por afuera de la intersección.

Ahora vamos a desarmar estas líneas en sus componentes (puntos), para ver el nodo que creamos con la unión:

``` sql
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
```

Nota que hicimos las dos consultas anidadas, es decir, primero hacemos la consulta anterior y luego la envolvemos con la consulta que nos regresa los puntos.

Ahora, para visualizar el resultado en QGis, agregamos un id a los puntos y los ponemos en una nueva tabla:

``` sql
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
```

Como podemos ver, creamos un punto el la auto-intersección. Ahora regresemos a la tabla gps_tracks y creemos un polígono:

``` sql
CREATE TABLE practica_2.gps_lakes AS
SELECT
ST_BuildArea(geom) AS lake,
track_id
FROM practica_2.gps_tracks;
```
Ahora pueden visualizar el lago en QGis.

**PREGUNTA**: ¿Qué hubiera pasado si no ponemos un nodo en la auto-intersección?



Hasta a quí lo que vimos es como construir líneas a partir de puntos y polígonos a partir de líneas cerradas (anillos). Para repasar estos conceptos es importante que leas el tutorial sobre geometrías de Boundless:
[Geometrías en PostGis](http://workshops.boundlessgeo.com/postgis-intro/geometries.html)

Referencia
=============

Para conocer más sobre el estándar de objetos espaciales (Simple Feature Access) puedes consultar el estándar (PDF) aquí:
[OpenGIS Implementation Specification for Geographic information - Simple feature access - Part 1: Common architecture](http://portal.opengeospatial.org/files/?artifact_id=25355)
 En dicho archivo encontrarás toda la información sobre las definiciones de los primitivos espaciales y sus representaciones.

En general, conviene tener a la mano el manual de PostGis:
[PostGis Manual](http://postgis.net/docs/manual-2.0/)
