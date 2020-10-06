--Checks commented out and dynamic SQL for setting sequence cache size
--select s.sequence_owner, doc.invalidations, s.sequence_name, doc.sharable_mem, s.cache_size, doc.loads, doc.executions, doc.locks, doc.child_latch
--select s.sequence_owner,s.sequence_name,round(sum((doc.locks/(s.cache_size+.25)+20)))
select 'alter sequence '||s.sequence_owner||'.'||s.sequence_name||' cache '||round(sum((doc.locks/(s.cache_size+.25)+20)))||';'
from v$db_object_cache doc, dba_sequences s
where doc.db_link is null
and s.cache_size<=20
and doc.name=s.sequence_name
and doc.type ='SEQUENCE'
and doc.child_latch >0
and s.sequence_owner not in ('SYS','PERSTAT')
group by s.sequence_owner,s.sequence_name