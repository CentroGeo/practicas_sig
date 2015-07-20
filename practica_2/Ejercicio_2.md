Ejercicio 2
================

En este ejercicio vamos a trabajar con el modelo __DE9IM__ para relaciones espaciales. La idea es entender cómo usar dicho modelo para seleccionar objetosa través de sus relaciones espaciales con otros objetos. Para el ejercicio vamos a introducir los objetos espaciales a mano y trabajaremos con geometrías sin referencia geográfica. Cuando no especificamos la referencia espacial, pero especificamos el tipo de datos como `geometry`, estamos diciendo que las coordenadas son planas.

Primero vamos a crear dos tablas para guardar los objetos de la práctica (recuerden cómo funciona el calificador `practica_2.`):

```sql
    CREATE TABLE practica_2.lineas (id serial primary key, geom geometry);
CREATE TABLE practica_2.poligonos ( id serial primary key, geom geometry);
```

Como pueden ver, creamos una tabla para líneas y otra para polígonos. Ahora vamos a popularlas:

```sql
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
```

Recordemos de la presentación que, las líneas 'buenas', son aquellas con las siguientes características:

1. Su interior tiene una intersección de dimensión 1 (linea) con el interior del polígono
2. Sus fronteras tienen una intersección de dimensión 0 (punto) con el interior del lago
3. Sus fronteras tienen una intersección de dimensión 0 (punto) con la frontera del lago
4. Sus interiores no se intersectan con el exterior del lago

La función `ST_Relate(geom1,geom2))` de PostGis nos regresa una representación _plana_ de la matriz de interacción de las dos geometrías, cada 3 caracteres representan un renglón de la matriz, los números representan la dimensión de la interacción y la letra F representa que la interacción no existe. Calculemos la matriz de interacción para nuestras geometrías:

```sql
SELECT lineas.id as l_id, poligonos.id as p_id, ST_Relate(lineas.geom, poligonos.geom)
FROM lineas, poligonos

```

El resultado, como ya dijimos, es la representación _plana_ de la matriz de interacción para cada línea con el polígono. Ahora, seleccionemos sólo las líneas que cumplen con el patrón que buscamos (¿cuál es ese patrón?). Para eso vamos a usar una versión de `St_Relate` que admite un tercer argumento: un _string_ que representa el patrón de relación, en esta versión `St_Relate` regresa verdadero o falso dependiendo de si las geometrías cumplen o no con el patrón especificado, veamos:

```sql
SELECT lineas.id as l_id, poligonos.id as p_id, ST_Relate(lineas.geom, poligonos.geom, '1FF00F212')
FROM lineas, poligonos;
```
Ahora vamos a usar este resultado para seleccionar las líneas que cimplen la condición que buscamos:

```sql

SELECT lineas.*
FROM lineas, poligonos
WHERE ST_Relate(lineas.geom, poligonos.geom, '1FF00F212');

```
Ya como última nota, si quisieramos repetir esto mismo, sobre tablas muy grandes, podemos hacer un query mucho más eficiente de la siguiente manera:

```sql

SELECT lineas.*
FROM lineas JOIN poligonos ON ST_Intersects(lineas.geom, poligonos.geom)
WHERE ST_Relate(lineas.geom, poligonos.geom, '1FF00F212');
```

Aquí ganamos eficiencia porque restringimos el cálculo de la matriz de interacción sólo a aquellas líneas que intersectan a los polígonos.
