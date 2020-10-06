--Search for duplicate SQL
select distinct a.hash_value, a.sql_text from v$sqlarea a, v$sqlarea b, dba_users c
where a.hash_value=b.hash_value and
a.parsing_user_id = c.user_id
and c.username='&OWNER'
and a.FIRST_LOAD_TIME != b.FIRST_LOAD_TIME