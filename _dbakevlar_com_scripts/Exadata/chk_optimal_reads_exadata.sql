﻿--Check optimal reads on Exadata
select owner, object_name, tablespace_name, ts#, dataobj#, statistic_name, value
from v$segment_statistics
where owner='$Schema'
and object_name='$TableName’
and statistic_name='optimized physical reads';
--take dataobj# and ts# and perform following in CellCLI
list flashcachcontent where objectnumber=<dataobj#> and tablespacenumber=<ts#> and dbuniquename=$dbname detail;