--db size report
col tablespace_name format 999,999,999 heading 'TABLESPACE|NAME'
col space_alloc format 999,999,999 heading 'MBytes|ALLOC'
col space_free format 999,999,999 heading 'MBytes|FREE'
col space_used format 999,999,999 heading 'MBytes|USED'
col pct_used format 999.9 heading 'PCT|USED'
col pct_free format 999.9 heading 'PCT|FREE'
set feedback off
drop table ts_usage
/
create table ts_usage (
tablespace_name varchar(75),
space_alloc number (30),
space_free number (30),
space_used number (30),
pct_used number (5,2),
pct_free number (5,2)
)
tablespace users
/
insert into ts_usage (tablespace_name, space_alloc)
select a.tablespace_name,
sum (a.bytes)/1024/1024 malloc
from dba_data_files a
group by a.tablespace_name
/
update ts_usage c
set space_free =
(select sum (b.bytes)/1024/1024 mfree
from dba_free_space b
where b.tablespace_name = c.tablespace_name
group by b.tablespace_name)
/
update ts_usage a
set space_used =
(select space_alloc-space_free
from ts_usage b
where b.tablespace_name = a.tablespace_name
)
/
update ts_usage a
set pct_used =
(select (space_used * 100) / space_alloc
from ts_usage b
where b.tablespace_name = a.tablespace_name
)
/
update ts_usage a
set pct_free =
(select (space_free * 100) / space_alloc
from ts_usage b
where b.tablespace_name = a.tablespace_name
)
/