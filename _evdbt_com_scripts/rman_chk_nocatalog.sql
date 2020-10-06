/**********************************************************************
 * File:	rman_chk_nocatalog.sql
 * Type:	SQL*Plus script
 * Author:	Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:	15-Oct-02
 *
 * Description:
 *	SQL*Plus script to create the RMAN_CHK package for use with
 *	the RMAN data repository in the database control files.
 *
 * Notes:
 *	The "redundancy check" functionality is not yet working, so
 *	whatever you enter to the parameter IN_REDUNDANCY does not
 *	yet make a difference.  I'll get that working soon...
 *
 *	If IN_DEBUG_FLAG is set to TRUE (default: FALSE), then debug
 *	output will be generated using DBMS_OUTPUT -- be sure to set
 *	SERVEROUTPUT ON when running from SQL*Plus...
 *
 * Installation:
 *	Create this package within the SYS schema on the "target"
 *	database.
 *
 * Modifications:
 *	EWiener	02aug02	written with TGorman
 *	TGorman	23jul04	added support for multi-instance OPS/RAC
 *			environments...
 *********************************************************************/
set echo on feedback on timing on

spool rman_chk_nocatalog

REM ==========================================================================
REM ...uncomment out the following lines if you prefer to create the RMAN_CHK
REM package in the SYSTEM schema, instead of SYS...
REM ==========================================================================
REM connect / as sysdba
REM 
REM grant select on v_$datafile to system;
REM grant select on v_$backup_datafile to system;
REM grant select on v_$backup_redolog to system;
REM grant select on v_$log_history to system;
REM 
REM connect system
REM ==========================================================================

set termout off
create or replace package rman_chk
as
	procedure recoverability (
			in_df_redundancy	in INTEGER,
			in_requested_pitr	in DATE,
			out_highest_bkup_time	out VARCHAR2,
			out_last_redo_start	out VARCHAR2,
			out_bkup_type		out VARCHAR2,
			in_debug_flag		in BOOLEAN default FALSE);
end rman_chk;
/
set termout on
show errors

set termout off
create or replace package body rman_chk
as
	/*======================================================================*
	 *======================================================================*/
	procedure find_oldest_df_bkup (
			in_redundancy		in INTEGER,
			out_earliest_scn	out NUMBER, 
			out_earliest_time	out DATE, 
			inout_bkup_type		in out VARCHAR2,
			in_debug_flag		in BOOLEAN)
	is
		i				integer;
		found				boolean;
		adequate_bkups			boolean := true;
		consistent_scn			v$backup_datafile.checkpoint_change#%type;

		cursor cur_df
		is
		select	file#,
			creation_change#
		from	v$datafile
		order by file#;

		cursor cur_bdf(in_file# in number, in_creation_change# in number)
		is
		select	checkpoint_change#,
			checkpoint_time
    		from	v$backup_datafile
    		where	file# = in_file#
    		and	creation_change# = in_creation_change#
    		order by checkpoint_change# desc;

	begin
		out_earliest_scn := power(10,125);

		/*
		 * initialize variables used for detecting whether datafile backup is "consistent"
		 * (i.e. "cold" backup) or "inconsistent" (i.e. "hot" backup)...
		 */
		consistent_scn := -1;

		/*
		 * loop through all of the datafiles...
		 */
		for df in cur_df loop
 
			i := 1;
			found := false;

			if in_debug_flag = TRUE then
				dbms_output.put_line('file#='||df.file#||',creation_change#='||df.creation_change#);
			end if;
 
			/*
			 * check "i"-th backup for each datafile...
			 */
			for bdf in cur_bdf(df.file#, df.creation_change#) loop
    
				if i < in_redundancy then

					i := i + 1;

				elsif i = in_redundancy then

					found := true;

					/*
					 * reset "consistent_scn" from initialized setting for first time only...
					 */
					if consistent_scn = -1 then
						consistent_scn := bdf.checkpoint_change#;
					end if;

					/*
					 * reset flag if inconsistent backup found...
					 */
					if consistent_scn <> bdf.checkpoint_change# then
						inout_bkup_type := 'INCONSISTENT';
					end if;

					/*
					 * find earliest SCN for datafile...
					 */
					if out_earliest_scn > bdf.checkpoint_change# then
						out_earliest_scn := bdf.checkpoint_change#;
						out_earliest_time := bdf.checkpoint_time;
					end if;

					if in_debug_flag = TRUE then
						dbms_output.put_line('...checkpoint-change#='||
								bdf.checkpoint_change#||
								', earliest-scn='||out_earliest_scn );
					end if;

					exit;

				end if;
 
			end loop;
  
			if not found then

				adequate_bkups := false;
				if in_debug_flag = TRUE then
					dbms_output.put_line('No Backup Datafile for File#='||df.file#); 
				end if;

			end if;
  
		end loop;

		if in_debug_flag = TRUE then
			dbms_output.put_line('start-scn='||out_earliest_scn);
		end if;

/*
		if not adequate_bkups then

			raise_application_error(-20002,
				'Datafiles do not have FULL/LEVEL0 backup with redundancy='||in_redundancy);

		end if;
*/

	end find_oldest_df_bkup;

	/*======================================================================*
	 *======================================================================*/
	procedure find_logs( 
			in_start_scn		in NUMBER,
			in_start_time		in DATE,
			in_bkup_type		in VARCHAR2,
			out_highest_bkup_time	out VARCHAR2,
			out_last_redo_start	out VARCHAR2,
			in_debug_flag		in BOOLEAN)
	is

		v_scn					v$backup_redolog.first_change#%type := -1;

		cursor backup_redologs(in_scn in NUMBER)
		is
		select	sequence#,
			first_change#,
			to_char(first_time, 'DD-MON-YYYY HH24:MI:SS') first_time,
			next_change#,
			to_char(next_time, 'DD-MON-YYYY HH24:MI:SS') next_time
		from	v$backup_redolog
		where	first_change# >= in_scn
		order by sequence#;

		cursor redologs(in_scn in NUMBER)
		is
		select	sequence#,
			first_change#,
			to_char(first_time, 'DD-MON-YYYY HH24:MI:SS') first_time,
			next_change#
		from	v$log_history
		where	first_change# >= in_scn
		order by sequence#;

	begin
		begin
			select	min(first_change#)
			into	v_scn
			from	v$backup_redolog
			where	first_change# <= in_start_scn
			and	next_change# >= in_start_scn;

			if v_scn is null then
				raise no_data_found;
			end if;

		exception

			when no_data_found then

				if in_bkup_type = 'CONSISTENT' then

					out_highest_bkup_time := to_char(in_start_time, 'DD-MON-YYYY HH24:MI:SS');
					out_last_redo_start := to_char(in_start_time, 'DD-MON-YYYY HH24:MI:SS');

					if in_debug_flag = TRUE then
						dbms_output.put_line('No backed-up archived redo logs following CONSISTENT backup');
					end if;

					return;
					
				else /* ...datafile backup was INCONSISTENT... */

					raise_application_error(-20002, 'No backed-up archived redo logs found');

				end if;

		end;

		if in_debug_flag = TRUE then
			dbms_output.put_line('archivelogs: dbf_scn='||in_start_scn||', rdo_first_scn='||v_scn);
		end if;

		/*
		 * find if there are backed up archive logs to cover all datafile backups...
		 */
		for l in backup_redologs(v_scn) loop

			if in_debug_flag = TRUE then
				dbms_output.put_line('backup_redolog: seq='||l.sequence#||': scn='||
					v_scn||', first_change#='||l.first_change#||', first_time="'||
					l.first_time||'", next_time="'||l.next_time||'"');
			end if;

			if v_scn <> l.first_change# then

				raise_application_error(-20003,
						'Unrecoverable - gap in backed-up archive redo logs from SCN='||
						l.first_change#||' ('||l.first_time||
						') until SCN='|| l.next_change#||' ('||l.next_time||')');

			end if;

			v_scn := l.next_change#;
			out_highest_bkup_time := l.next_time;

		end loop;

		/*
		 * now find out if the unbacked-up redo log files are up-to-date or not...
		 */
		for l in redologs(v_scn) loop

			if in_debug_flag = TRUE then
				dbms_output.put_line('redolog: seq='||l.sequence#||': scn='||
						v_scn||', first_change#='|| l.first_change#||
						', first_time="'||l.first_time||'"');
			end if;

			if v_scn <> l.first_change# then

				raise_application_error(-20004,
						'Unrecoverable - gap in non-backed-up archive redo logs from SCN='||
						l.first_change#||' ('||l.first_time||
						') until SCN='|| l.next_change#);

			end if;

			v_scn := l.next_change#;
			out_last_redo_start := l.first_time;

		end loop;

		if out_last_redo_start is null then
			out_last_redo_start := out_highest_bkup_time;
		end if;

	end find_logs;

	procedure recoverability (
			in_df_redundancy	in INTEGER,
			in_requested_pitr	in DATE,
			out_highest_bkup_time	out VARCHAR2,
			out_last_redo_start	out VARCHAR2,
			out_bkup_type		out VARCHAR2,
			in_debug_flag		in BOOLEAN default FALSE)
	is
		v_start_scn			number;
		v_start_time			date;
	begin 

		out_bkup_type := 'CONSISTENT';

		find_oldest_df_bkup(in_df_redundancy,
				    v_start_scn, v_start_time, out_bkup_type,
				    in_debug_flag);

		find_logs(v_start_scn, v_start_time, out_bkup_type,
			  out_highest_bkup_time, out_last_redo_start,
			  in_debug_flag);

		if in_requested_pitr is not null then

			if to_date(out_last_redo_start, 'DD-MON-YYYY HH24:MI:SS') <
			   in_requested_pitr then

				raise_application_error(-20005, 'Cannot recover to requested point-in-time "' ||
					to_char(in_requested_pitr, 'DD-MON-YYYY HH24:MI:SS') || '"');

			end if;

		end if;

	end recoverability;

end rman_chk;
/
set termout on
show errors

spool off
