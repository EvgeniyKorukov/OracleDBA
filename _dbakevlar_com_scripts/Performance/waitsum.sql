column event    format a55
column avg_wait format 99,990.0000

break on report
compute sum of count on report

set feed off

select event, count(*) count, AVG(seconds_in_wait) avg_wait
from v$session_wait
where event not in ('SQL*Net message to client',
                    'SQL*Net message from client',
                    'smon timer',
                    'pmon timer',
                    'rdbms ipc message',
                    'Streams AQ: qmn slave idle wait',
                    'Streams AQ: qmn coordinator idle wait',
                    'SQL*Net more data to client',
                    'Streams AQ: waiting for time management or cleanup tasks')
group by event
/

prompt *note - avg_wait time is in seconds
prompt

set feed on