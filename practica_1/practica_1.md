Este es el instructivo de la primera práctica de SIG Usando Postgres/PostGis.
=============

Lo primero que tienes que hacer es extraer el contenido del zip con el censo 2010. Para esta práctica sólo vamos a utilizar
 las carpetas del DF y del Estado de México.

 Una vez que hayas extraido las carpetas necesitas crear una base de datos en postgres con la extensión Postgis (aquí puedes ver un tutorial sobre cómo hacerlo:
 [Crear una base de datos espacial](http://workshops.boundlessgeo.com/postgis-intro/creating_db.html).

 Lo primero que necesitamos hacer es cargar los _shapefiles_ que vamos a utilizar en la base de datos que acabamos de crear (asumiremos que la base de datos se llama practica_sig). Para esto, en linux abrimos una terminal en la carpeta donde está el shape de las manzanas del DF y ejecutamos el siguiente comando(*):

    shp2pgsql -c -s 4326 -I  -W LATIN1 df_manzanas.shp public.merge_manzanas | sudo -u postgres psql practica_sig

 (*) Para una descripción completa del cargador 'shp2pgsql' puedes consultar aquí: [manpage shp2pgsql](http://man.cx/shp2pgsql).
para un instructivo más detallado: [tutorial shp2pgsql](http://suite.opengeo.org/docs/dataadmin/pgGettingStarted/shp2pgsql.html)

Ahora vamos a agregar la capa de manzanas del Estado de México pero en lugar de crar una nueva tabla las vamos a pegar en la tabla que ya hicimos ('public.manzanas_zmvm'):

    shp2pgsql -a -s 4326 -W LATIN1 mex_manzanas.shp public.merge_manzanas | sudo -u postgres psql practica_sig'

 Nota que cambiamos el switch -c por el -a, esto es para subir el shape en modo _append_ en lugar de crear una nueva tabla. Además quitamos el modificador -I para no crear un índice espacial (el índice ya está creado y volverlo a hacer arrojaría error).

 Hay otras formas más amigables de subir capas a la base de datos, por ejemplo la interfaz gráfica de `shp2pgsql`, búscala en el menú de inicio de windows. En escencia funciona igual que la linea de comando, utiliza esta herramienta para subir las capas de AGEBS y de calles. Recuerda que siempre vamos a querer crear una sola tabla con el _merge_ de los datos para el DF y el Estado de México.

 Finalmente, agregamos otras dos capas que están incluidas en el directorio _data_ de este repositorio:

    shp2pgsql -c -s 32614 -I  -W LATIN1 estaciones_metro_final.shp public.estaciones_metro | sudo -u postgres psql practica_sig'

    shp2pgsql -c -s 32614 -I  -W LATIN1 limite_metropolitano.shp public.limite_metropolitano | sudo -u postgres psql practica_sig'

  Nota que estas dos capas están en una proyección diferente (_32614_ quiere decir UTM Zona 14 Norte elipsoide WGS84), más adelante regrersaremos a esto.

  Pues hemos terminado de subir los datos para la práctica 1, ahora podemos proceder a hacer las consultas y a la diversión de Postgis. Ten en cuenta que para ejecutar las consultas y visualizarlas necesitas algun cliente para la base de datos [PGAdmin III](http://www.pgadmin.org/) provee una interfaz amigable para administrar las bases de datos y hacer consultas pero no puedes visualizar capas geográficas. [QGis](http://www.qgis.org/en/site/), provee algunas funcionalidades de consulta y administración y además permite visulizar y analizar información geográfica.

## Parte 1 Consultas básicas.

  Lo primero que vamos a hacer es proyectar las geometrías de las manzanas para que sean compatibles con las estaciones del metro y el límite metropolitano.
  Es mejor proyectar las manzanas para que todo está en coordenadas planas, de ese modo los cálculos geométricos son mucho más rápidos:

  ``` sql
    ALTER TABLE merge_manzanas
      ALTER COLUMN geom
      TYPE Geometry(Polygon, 32614)
      USING ST_Transform(geom, 32614);
  ```
  Repite la misma operación para todas las capas que estén en coordenadas geográficas (SRID: 4326)

  Ahora vamos a cortar las manzanas con el polígono del límite metropolitano (lo que se llama un clip, pues) y meter el resultado en la tabla  `manzanas_zmv`:

  ``` sql  
  create table manzanas_zmv as(
  select merge_manzanas.*
  from merge_manzanas
  inner join limite_metropolitano on
  st_intersects(limite_metropolitano.geom,merge_manzanas.geom)
  )
  ```
  Nota como lo que hicimos fue en realidad un inner join pero como condición utilizamos una relación espacial: `st_intersects`

  Ahora vamos a crear un índice espacial sobre la geometría:

``` sql
  create index manzanas_zmvm_gix on manzanas_zmvm using GIST(geom);
```
  **TAREA:** investiga qué son y para qué sirven los índices espaciales.


  Antes de continuar tenemos que checar la consistencia de los datos, por ejemplo, ver si los gid son únicos:

  ```sql
  select count(*) from manzanas_zmvm  group by gid order by count(*) desc;
  ```
  ¿Por qué no son únicos los gids?

  Como la tabla tiene unos gid's repetidos, alteramos la columna para que sean únicos:

  ```sql
  CREATE SEQUENCE "manzanas_zmvm_gid_seq";
  update manzanas_zmvm set gid = nextval('"manzanas_zmvm_gid_seq"');
  ```

  Creamos los constraints necesarios y agregamos un PK:

  ```sql
  ALTER TABLE manzanas_zmvm ALTER COLUMN "gid" SET NOT NULL;
  ALTER TABLE manzanas_zmvm ADD UNIQUE ("gid");
  ALTER TABLE manzanas_zmvm ADD PRIMARY KEY ("gid");
  ```

  Ahora podemos empezar a hacer algunas preguntas interesantes, por ejemplo:

  ¿Cuántas manzanas quedan a 500 metros de cada estación del metro?

  ```sql
  select foo.* from
  (with buf as (select st_buffer(estaciones_metro.geom,500.0) as geom , estaciones_metro.nombreesta as estacion from estaciones_metro)
  select count(manzanas_zmvm.gid), buf.estacion from manzanas_zmvm join buf on
  st_intersects(buf.geom,manzanas_zmvm.geom)
  group by buf.estacion) as foo;
  ```

  ¿Cuánta gente vive a 500 m de una estación del metro?

  _Nota: La columna pob1 contiene la población de cada manzana_

  ```sql
  select foo.* from
  (with buf as (select st_buffer(estaciones_metro.geom,500.0) as geom , estaciones_metro.nombreesta as estacion from estaciones_metro)
  select sum(manzanas_zmvm.pob1), buf.estacion from manzanas_zmvm join buf on
  st_intersects(buf.geom,manzanas_zmvm.geom)
  group by buf.estacion) as foo;
  ```

  __PUNTO EXTRA:__ ¿Cuántas personas no viven a 500 metros de una estación de metro?

  _Hint: Tienes que sumar el resultado de la expresión de arriba y restarla de la población total.
  Como es el primer quiz, puedes hacerlo en dos querys_

  __EJERCICIO # 1.__- En los datos del Censo encontrarás shapes con las calles del DF y del Estado de México, así como de las AGEBS. Agrega estos shapes como capas en Postgis y repite los pasos 1 a 6 de este archivo para obtener un corte de las calles y de las AGEBS con la forma de la ZMVM en tablas indexadas espacialmente y con llave primaria (PK)

## Parte 2. Un ejercicio

  Lo que vamos a hacer en esta parte de la práctica es completar todo un flujo de trabajo para obtener mapas de cantidad y densidad de población de habitantes por colonia.

  Lo primero que vamos a hacer es relacionar las tablas de manzanas (que es donde tenemos datos de población), con la de colonias. Haciendo una unión espacial podemos asignar un identificador de colonia a la capa de manzanas:

  ```sql
  select  manzanas_zmvm.gid, manzanas_zmvm.cvegeo, colonias.id_colonia,manzanas_zmvm.geom
  into manzanas_colonias
  from manzanas_zmvm join colonias on st_intersects(colonias.geom, manzanas_zmvm.geom);
  ```
  Noten como al hacer un `select into`, creamos implícitamente la tabla `manzanas_colonias`.


  __EJERCICIO # 2:__ Crea un índice espacial sobre la geometría y agrega una llave primaria a la tabla que acabas de crear.

  __EJERCICIO # 3:__ De la misma forma en que creamos la tabla manzanas_colonias, crea una tabla que una la geometría de las calles con el id de las colonias
  (recuerda crear su propio índice espacial y llave primaria).

  Fíjense que ahora tenemos una manera de unir las tablas de manzanas y de colonias, de hecho, sería relatívamente fácil agregar la población de las manzanas de acuerdo al identificador de colonia y así obtener la población en cada colonia. Lo que vamos a hacer es un poco distinto: para acabar con mapas más bonitos, vamos a conservar la geometría de las manzanas pero agregada por las colonias, es decir, vamos a crear multipolígonos para representar a las colonias:

  ```sql
  select st_union(geom) as geom , id_colonia,
        min(nombre) as nombre, min(cp) as cp
  into manzanas_union
  from manzanas_colonias
  group by id_colonia;
  ```

  Aquí estamos usando una función agregada (noten la cláusula `group by`), para unir la geometría de las manzanas en un sólo multipolígono para cada colonia.

  Ahora sí, vamos a pegarle a nuestra tabla `manzanas_union`los datos de población:

  ```sql
  create table pob_colonias as
  select o.pob, u.nombre, u.cp, u.geom, u.id_colonia from
  (select sum( q.pob) as pob, q.id_colonia
  from
  (
  select  m.pob1 as pob, c.id_colonia as id_colonia from manzanas_zmvm m
  join manzanas_colonias c
  on m.cvegeo = c.cvegeo) as q
  group by q.id_colonia) as o
  join manzanas_union u
  on u.id_colonia = o.id_colonia
  ```

  Como puedes ver, esta es una consulta bastante más complicada, pero en realidad lo que hacemos es relativamente fácil si lo lees de adentro hacia afuera: en el _query_ más interno unimos las capas de manzanas y de colonias, en el _query_ externo agregamos por colonia y luego unimos todo a la geometría de la capa que hicimos con la unión geométrica de las manzanas.

  Lo único que hace falta ahora es calcular la densidad de población de cada colonia. Para eso vamos a agregar una columna en donde vamos a calcular el area de cada colonia:

  ```sql
  alter table pob_colonias add column area float
  ```
  Y calcular el area:

  ``` sql
  update  pob_colonias set area = st_area(geom)
  ```

  Ahora vamos a crear la columna densidad y popularla con el cociente entre población y area:

  ``` sql
  alter table pob_colonias add column densidad float;
  update pob_colonias set densidad = ((pob::float)/area)*10000;
  ```

  Cuando hacemos `pob::float` estamos diciendo que queremos usar los valores de población como número de punto flotante, para que no se redondeen los valores, al final multiplicamos por 10,000 para obtener habitantes por hectarea, que es la medida normal.

  Finalmente, haz unos mapas con lo que obtuvimos.
