--Checks for data dictionary corruption
Set verify off        
Set space 0        
Set line 120        
Set heading off        
Set feedback off         
Set pages 1000         
Spool analyze.sql         
        
Select 'Analyze cluster "'||cluster_name||'" validate structure cascade;'         
from dba_clusters         
where owner='SYS'        
union        
Select 'Analyze table "'||table_name||'" validate structure cascade;'         
from dba_tables        
where owner='SYS' and partitioned='NO' and (iot_type='IOT' or iot_type is NULL)        
union        
Select 'Analyze table "'||table_name||'" validate structure cascade into invalid_rows;'         
from dba_tables        
where owner='SYS' and partitioned='YES';        
        
spool off