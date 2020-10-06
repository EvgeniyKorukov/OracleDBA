--Library Statistics
select
namespace,
gets locks,
gets - gethits loads,
pins,
reloads,
invalidations
from
sys.v_$librarycache
where
gets > 0
order by
2 desc
/