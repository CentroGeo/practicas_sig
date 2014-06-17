create extension pgrouting;

alter table practica_3.calles_zmvm add column source integer;

alter table practica_3.calles_zmvm add column target integer;

select pgr_createTopology('practica_3.calles_zmvm', 0.000001,'geom','gid');