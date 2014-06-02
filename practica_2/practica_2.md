Instructivo para la segunda práctica de SIG Usando Postgres/PostGis. 
Primitivos espaciales; armando y desarmando; relaciones espaciales.
=============

En esta práctica trataremos dos cuestiones fundamentales sobre la representación en base de datos de información geoespacial:
1. Los primitivos espaciales (puntos, lineas y polígonos) y sus tipos agregados
2. Las relaciones espaciales

Para esta práctica utilizaremos las capas de datos que puedes encontrar en la carpeta 'practica_2/data/' de este repositorio. 
Recuerda que antes de pasar al archivo sql, debes subir todos los _shapes_ de dicha carpeta a tablas en Postgis, para efectos del resto del instructivo, asumiremos que subiste las capas en una base de datos llamada practicas_sig y en el esquema practica_2, como se ve en el siguiente esquema:

	+practicas_sig
		+practica_1
			+tablas...
		+practica_2
			+tablas...

Ejercicios		
=============

1. En el primer ejercicio vamos construir un polígono a partir de una serie de puntos (tomados con un GPS). Una vez que tengas tus tablas en una base de datos, puedes proseguir al archivo practica_2_Ej_1.sql

2. En el segundo Ejercicio de la práctica vamos a explorar las relaciones espaciales entre diferentes objetos en PostGis. Todo los que necesitas para esta práctica lo encuentras en el archivo practica_2_Ej_2.sql



Referencia
=============

Para conocer más sobre el estándar de objetos espaciales (Simple Feature Access) puedes consultar el estándar (PDF) aquí:
[OpenGIS Implementation Specification for Geographic information - Simple feature access - Part 1: Common architecture](http://portal.opengeospatial.org/files/?artifact_id=25355)
 En dicho archivo encontrarás toda la información sobre las definiciones de los primitivos espaciales y sus representaciones.
 
Para una introducción a los objetos geométricos, puedes seguir el tutorial de Boundless:
[Geometrías en PostGis](http://workshops.boundlessgeo.com/postgis-intro/geometries.html)

En general, conviene tener a la mano el manual de PostGis:
[PostGis Manual](http://postgis.net/docs/manual-2.0/)
