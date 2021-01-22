[Laboratorio de Sistemas de Información Geográfica](http://centrogeo.github.io/practicas_sig/)

Bases de datos geoespaciales
============

Esta es la página principal del laboratorio de la clase de Sistemas de Información Geográfica (SIG) de la [Maestría en Ciencias de Información Geoespacial](https://www.centrogeo.org.mx/posgrados/maestria-en-ciencias-de-informacion-geoespacial) de CentroGeo. El laboratorio trata de desarrollar en el estudiante tanto las capacidades básicas para trabajar con bases de datos geoespaciales, como los conceptos fundamentales debajo del modelo vectorial de datos.

En esta pagina encontrarás todo el material necesario para trabajar en el laboratorio, así como las tareas designadas para cada práctica. 

Las prácticas están enumeradas y dentro de cada una encontrarás los enlaces para descargar los archivos y material de apoyo. En la última sección de cada una de ellas, están las instrucciones para realizar las tareas y ejercicios extra corr espondientes. 

Descripción General del Curso 
=============
La idea general del laboratorio es introducir al estudiante en los conceptos fundamentales del manejo de datos vectoriales en SIG. A través de las diferentes prácticas que plantea el curso, el alumno desarrollará capacidades básicas de trabajo en el maejador de bases de datos relacionales (RDMS) [PostgreSQL](https://www.postgresql.org/) y su extensión para objetos geográficos [PostGIS](https://postgis.net/). Al mismo tiempo, el alumno desarrollará una comprensión sobre los conceptos fundamentales de las estructuras de datos relacionales aplicadas a los SIG, así como del modelo jerárquico de datos vectoriales.

Prácticas
=============

## Práctica 1: Introducción a PostgreSQL/PostGIS
Esta práctica está diseñada para desarrollar familiaridad con lñas herramientas que se utilizarán en el resto del curso. Aprenderás cosas como crear una base de datos con soporter de objetos espaciales, conectarte desde [QGIS](https://www.qgis.org/en/site/) y visualizar datos. También contiene algunas consultas básicas orientadas a desarrollar una primera visualización.

[**Práctica 1:** Introducción a PostGis](./practica_1/practica_1.md)

## Práctica 2: Primitivos espaciales
En esta práctica aprenderás los fundamentos del modelo jerárquico de datos vectoriales. A partir de un conjunto de puntos construiremos líneas y polígonos.

[**Práctica 2:** Primitivos Espaciales](./practica_2/Ejercicio_1.md)

## Práctica 3: Modelo de Interacciones Espaciales (DE9IM)
Esta práctica expone la matriz de relaciones espaciales y su uso para seleccionar objetos a partir de las relaciones que guardan entre ellos

[**Práctica 3:** Modelo de Interacciones Espaciales (DE9IM)](./practica_2/Ejercicio_2.md)

## Práctica 4: Etiquetado topológico de intersecciones
Hay muchas formas de etiquetar las intersecciones de un conjunto de polígonos, en esta práctica vamos a utilizar una muy poco usual. El objetivo es reforzar la comprensión del modelo jerárquico de datos vectoriales y desarrollar una intuición sobre el modelo topológico de datos

[**Práctica 4:** Etiquetado topológico de intersecciones](./practica_2/Ejercico_3.md)

## Práctica 5: Introducción a pgRouting
Un tema cásico y muy útil dentro de los SIGs es el análisis de redes de transporte. En esta práctica desarrollaremos los conceptos básicos detrás del modelo de redes en SIG y utilizaremos la extensión [pgRouting](https://pgrouting.org/) para hacer cálculos de rutas

[**Práctica 5:** Introducción a pgRouting](./practica_3/README.md)

## Práctica 6 Trabajando con redes de transporte reales
En esta práctica trabajaremos con redes más complejas y estudiaremos formas de crear áreas de servicio a partir de nodos centrales.

[**Práctica 6:** Trabajando con redes de transporte reales](./ejercicios_varios/README.md)


### Colaboradores

#### Diseño del curso y contenidos:

* Karime González Zuccolotto
* Pablo López Ramírez
* Alexis Navarrete Puebla




