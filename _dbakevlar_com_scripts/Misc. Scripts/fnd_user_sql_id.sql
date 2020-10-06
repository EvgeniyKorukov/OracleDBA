--Find Out Who belongs to SQL_ID in History
select
du.username, dsh.* from DBA_HIST_ACTIVE_SESS_HISTORY dsh, dba_users du
where
dsh.sql_id='<SQL_ID>'
and
dsh.user_id=du.user_id