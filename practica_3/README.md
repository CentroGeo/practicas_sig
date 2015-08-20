Práctica 3 Análisis de redes con pgrouting
=========

En esta práctica vamos a hacer análisis de rutas utilizando la extensión [pgrouting](http://pgrouting.org/) para PostGis. Lo primero que tenemos que hacer es instalar dicha extensión:

* Del archivo de datos de la práctica (la carpeta debe estar en el escritorio), extrae el contenido de la carpeta `pgrouting-pg92-binaries-2.0.0w64gcc48.zip` y copia los archivos en la ruta de instalación de postgres: `C:\Program Files\PostgreSQL\9.2`

Para probar que la extensión quedó instalada correctamente, desde una consola de sql (conectada a alguna de las bases de datos que hemos utilizado), de pgAdmin escribe:

````sql
CREATE EXTENSION pgrouting;
````

Si la consulta no regresa ningún error, la extensión quedó instalada correctamente.

## Parte I: preparación de los datos


Para esta práctica vamos a crear una base de datos nueva, por ejemplo, `practica_3`. No es necesario que habilites la extensión PostGis, los datos los vamos a recuperar de un respaldo. Sigue las instrucciones del profesor para restaurar la base de datos a partir del archivo `practica_3.backup`. Si el proceso no regresa error, entonces ya tienes todo listo!

Como puedes ver, la base de datos contiene una tabla que se llama calles, ábrela en Qgis y examínala.

Una cosa interesante es que tenemos líneas que no representan calles, sino líneas de metro, ferrocarril, andadores peatonales, etc. Entonces, pensando en crear rutas para automóviles, es necesario remover dichás líneas. Primero identifiquemos las cosas que queremos eliminar:

````sql
select distinct type from calles;
````

Esto nos regresa los diferentes tipos de segmentos y a partir de allí podemos hacer una selección de lo que no nos interesa:

````sql
select distinct type from calles;
````

Para ver una selección particular de tipos ejecuta:

````sql
select * from calles
where type in ('cycleway','monorail');
````

sustituyendo por los tipos que te parezca que debemos conservar.

Antes de borrar datos de la tabla de calles, creemos una copia para conservar los datos originales:

````sql
create table calles_completa as table calles;
````

Ahora sí, vamos a borrar las calles que no nos interesan (haz tu propia selección, la puedes ir viendo poco a poco para decidir):

````sql
delete from calles
where type not in ('primary','secondary','motorway','tertiary','tertiary link','motorway link',
                'secondary link', 'primary link','living street','residential','road')
````

##Parte II: Creación de la topología y pesos

Una vez que tenemos sólo las calles que nos interesan, vamos a usar pgrouting para crear la topología de red sobre las calles. Lo primero que necesitamos es agregar dos campos para almacenar los nodos de orígen y destino de cada segmento:

````sql
alter table calles add column source integer;
alter table calles add column target integer;
````

Ahora, vamos a llamar a la función `select pgr_createTopology('lines', tolerancia, 'geom', 'id');`, para crear los nodos y asignar los identificadores correspondientes. Los argumentos de la función son los siguientes:

+ **lines**: Tabla con las geometrías
+ **tolerancia**: Distancia (en las unidades de la proyección) máxima para considerar dos lineas unidas.
+ **geom**: Columna con geometría.
+ **id**: columna con el identificador único.

En nuestro caso:

````sql
select pgr_createTopology('calles', 0.0001, 'geom', 'gid');
````

Como pueden ver, esta función crea la tabla `calles_vertices_pgr`, idealmente esta tabla contiene todos los nodos de la red, examínenla en Qgis. Como pueden ver, aún faltan nodos en algunas intersecciones, la razón es que la geometría de las calles es de tipo MultiLinestring, es decir, es una colección de líneas (piensen en qué sentido tiene calcular inicio y fin sobre una colección), entonces vamos a tratar de convertir las geometrías a linestring simple, para poder poner nodos en las intersecciones. Primero creamos otra copia, para no romper la original:

````sql
create table calles_prueba as table calles;
````

Luego cambiamos el tipo de geometría:

````sql
ALTER TABLE calles_prueba
  ALTER COLUMN geom
  TYPE Geometry(Linestring, 32614)
  USING st_geometryn(geom, 1)
````

Observen en Qgis si perdimos algún segmento.

Como no se modifica nada, entonces podemos trabajar sobre esta tabla, intentemos crear la topología nuevamente:

````sql
select pgr_createTopology('calles_prueba', 0.0001, 'geom', 'gid');
````

eso se puede deber a que la geometría no está creada adecuadamente, es necesario asegurarnos de que cada intersección tenga un nodo, para esto podemos usar la función (pgr_nodeNetwork)[http://docs.pgrouting.org/dev/src/common/doc/functions/node_network.html#pgr-node-network]:

SELECT * FROM pgr_nodeNetwork('calles', 0.000001, 'gid', 'geom', 'calles_noded');

ALTER TABLE calles
  ALTER COLUMN geom
  TYPE Geometry(Linestring, 32614)
  USING st_geometryn(geom, 1)


##Preguntas

+ Explica las diferencias entre los algoritmos de Dijkstra y A*
+ Bajo qué condiciones recomendarías usar uno u otro algoritmo.
