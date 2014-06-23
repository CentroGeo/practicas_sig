
--Esta primera sección contiene las consultas del README, si ya las
--ejecutaste no es necesario que las vuelvas a correr.

--Crear la extensión pgrouting
create extension pgrouting;

--Crear las columnas source y target
ALTER TABLE practica_3.calles_zmvm ADD COLUMN source integer;
ALTER TABLE practica_3.calles_zmvm ADD COLUMN target integer;

--Ahora agregamos columnas para guardar los puntos de inicio y fin de
--cada segmento. Esto sirve principalmente para establecer los sentidos
--de las calles.
alter table practica_3.calles_zmvm
ADD COLUMN x1 double precision,
ADD COLUMN y1 double precision,
ADD COLUMN x2 double precision,
ADD COLUMN y2 double precision;

UPDATE practica_3.calles_zmvm SET
x1 = st_x(st_startpoint(geom)),
y1 = st_y(st_startpoint(geom)),
x2 = st_x(st_endpoint(geom)),
y2 = st_y(st_endpoint(geom));
--Ahora tenemos en las columnas xi, las coordenadas x de los inicios y finales
--de los segmentos y en las columnas yi las coordenadas y.

--Ahr

--Ahora vamos a agregar una columna con la longitud de cada segmento:

ALTER TABLE practica_3.calles_zmvm ADD COLUMN length numeric;
UPDATE practica_3.calles_zmvm SET length = st_length(geom)

--Crear la topología de redes
SELECT pgr_createTopology('practica_3.calles_zmvm', 0.001,'geom','gid');
