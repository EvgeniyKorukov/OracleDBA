--Check Oracle Patch
set serveroutput on
-- Note: Please enter Patch number in place of and , e.g '3240000'
--when p_patchlist:= p_patch_array_type('3240000','3460000','4204335','4125550','3942483','4733943'):
 
DECLARE
TYPE p_patch_array_type is varray(10) of varchar2(10);
--
p_patchlist p_patch_array_type;
p_appltop_name varchar2(50);
p_patch_status varchar2(15);
p_appl_top_id number;
--
CURSOR alist IS
select appl_top_id, name
from ad_appl_tops;
--
procedure println(msg in varchar2)
is
begin
dbms_output.put_line(msg);
end;
--
BEGIN
open alist;
--
p_patchlist:= p_patch_array_type('','');
--
LOOP
FETCH alist INTO p_appl_top_id,p_appltop_name;
EXIT WHEN alist%NOTFOUND;
--
IF p_appltop_name NOT IN ('GLOBAL','*PRESEEDED*')
THEN
println(p_appltop_name || ':');
for i in 1..p_patchlist.count
loop
p_patch_status := ad_patch.is_patch_applied('11i',p_appl_top_id,
p_patchlist(i));
println('..Patch ' || p_patchlist(i) || ' was ' || p_patch_status);
end loop;
END if;
println('.');
END LOOP;
--
close alist;
END;
/