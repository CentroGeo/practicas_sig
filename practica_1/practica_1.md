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

 Ahora puedes continuar con el código de [practica_1.sql](https://github.com/plablo09/practicas_sig/blob/master/practica_1/practica_1.sql)
