rem Script Description: Reports the space usage of data files.
rem
rem Output file: file_space.txt
rem
rem Prepared By: Peter Guo
rem
rem
rem Usage Information: SQLPLUS SYS/pswd
rem @file_space.sql
rem
column free_space format 99999.99
column all_space format 99999.99
column used_space format 99999.99
column filename format a35
column tsname format a15
column used_pct format 99.99
create or replace view File_free as
select fn.file_id file_id,
sum(fs.bytes)/1000000 free_space
from sys.dba_data_files fn,
sys.dba_free_space fs
where fn.file_id=fs.file_id
group by fn.file_id;
spool C:\file_space.txt;
select fn.file_name filename,
fn.tablespace_name tsname,
ff.free_space free_space,
fn.bytes/1000000 All_space,
fn.bytes/1000000 - ff.free_space used_space,
1 - ff.free_space/(fn.bytes/1000000) used_pct
from sys.dba_data_files fn,
file_free ff
where fn.file_id=ff.file_id
order by filename;
spool off