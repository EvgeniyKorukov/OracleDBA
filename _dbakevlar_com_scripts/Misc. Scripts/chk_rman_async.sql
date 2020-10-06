--Rman Backups check Async
select device_type, type, filename, to_char(open_time, 'mm/dd/yyyy hh24:mi:ss') open,
to_char(close_time, 'mm/dd/yyyy hh24:mi:ss') close, elapsed_time ET, effective_bytes_per_second EPS
from v$backup_async_io
where close_time >sysdate -1
order by close_time desc
/