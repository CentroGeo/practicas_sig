Práctica 3 Análisis de redes con pgrouting
=========

En el primer ejercicio vamos a utilizar la extensión pgrouting para crear una
topología de redes a la tabla de calles_zmvm en el esquema practica_3

En primer lugar, vamos a copiar la tabla calles_zmvm  al esquema practica_3:

````sql
CREATE TABLE practica_3.calles_zmvm AS
TABLE practica_1.calles_zmvm;
````

Para hacer análisis de redes en PsotGis, necesitamos crear la extensión pgrouting
en la base de datos:

````sql
CREATE EXTENSION pgrouting;
````
Nota: pgrouting es una extensión de PostGis para hacer análisis de redes, la
documentación completa la puedes encontrar aqui:
 [Docs de pgrouting](http://docs.pgrouting.org/2.0/en/doc/index.html)

Ahora, como recordarán del ejercicio en Arc, necesitamos crear columnas en la tabla que nos indiquen
origen y destino para crear una topología de red:

````sql
ALTER TABLE practica_3.calles_zmvm ADD COLUMN source integer;
ALTER TABLE practica_3.calles_zmvm ADD COLUMN target integer;
````

Ahora estamos listos para proceder a los ejercicios, abre el archivo practica_3.sql


##Preguntas

+ Explica las diferencias entre los algoritmos de Dijkstra y A*
+ Bajo qué condiciones recomendarías usar uno u otro algoritmo.
