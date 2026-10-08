/**
 *  This test case verifies CBRD-27041: a driving heap scan that reads records from a private
 *  copy of each heap page returns the same rows as the per-record read it replaced.
 *
 *  Before the fix, the outer table of a nested-loop join, or a table whose block lost the fixed
 *  scan to a correlated or HAVING subquery, was read with one page fix per record. The fix copies each
 *  page once (serial and parallel) and reads home records from the copy, other records from the page.
 *
 *  No hint or parameter turns the copy off, so this is a correctness test and the pre-fix build
 *  also passes. Each tested query has a twin that reads the table without the copy (single table,
 *  inner side or FOR UPDATE), and the two result blocks must be identical. Parallel cases assert
 *  the gather token in the trace (CTP masks digits).
 *
 *  Coverage:
 *    Case 1:  outer over home, relocated and overflow records, inner index lookup
 *    Case 2:  outer when the inner is a sequential scan, two and three tables
 *    Case 3:  parallel outer, buildvalue and mergeable list gathers
 *    Case 4:  single table whose select list drops the fixed scan (subqueries, INDEX_CARDINALITY)
 *    Case 5:  single table with a correlated EXISTS subquery
 *    Case 6:  single table with a subquery in HAVING
 *    Case 7:  own uncommitted update, relocation, delete and insert, serial and parallel
 *    Case 8:  partitioned outer, every partition and pruned to the middle ones
 *    Case 9:  parallel partitioned outer
 *    Case 10: empty and one-row outer tables
 *    Case 11: scan stopped by LIMIT at the first, a middle and the last row
 *    Case 12: class hierarchy, two classes read as the outer
 *    Case 13: db_serial (no MVCC) as the outer
 *    Case 14: INSERT SELECT into the same table and DELETE joined to the outer
 *    Case 15: the same join with FOR UPDATE, which never reads from the copy
 */

drop table if exists t_one, t_seq, t_dim, t_drive, t_part, t_empty, t_single, t_copy;
drop table if exists t_derived;
drop table if exists t_base;
drop serial if exists serial_alpha;
drop serial if exists serial_beta;
set system parameters 'group_concat_max_len=1048576';

-- one row and no index: as the inner side it is the fixed scan, so the other table is read from the copy
create table t_one (k int);
insert into t_one values (1);
-- numbers for building incompressible long values
create table t_seq (n int);
insert into t_seq select rownum from db_class a, db_class b limit 200;
-- primary key lookup as the inner side, the TPC-H q12 shape
create table t_dim (g int primary key, w int);
insert into t_dim select n, n * 10 from t_seq where n <= 13;
-- 6000 rows on about 215 heap pages (6x the 32-page parallel threshold of CTP test_mode), grp is the bit length of id: groups of 1, 2, 4 ... 2048 and 1905 rows
create table t_drive (id int, grp int, pad varchar(40000));
insert into t_drive select rownum, length(bin(rownum)), sha2(rownum, 512) || sha2(rownum + 100000, 512) || sha2(rownum + 200000, 512) from db_class a, db_class b, db_class c limit 6000;
-- 120 rows widened to 3072 characters move to other pages (relocated records)
update t_drive d set pad = (select group_concat(sha2(d.id * 1000 + s.n, 512) order by 1 separator '') from t_seq s where s.n <= 24) where mod(d.id, 50) = 0;
-- 3 rows of 20480 characters do not fit in a 16K page (overflow records)
update t_drive d set pad = (select group_concat(sha2(d.id * 1000 + s.n, 512) order by 1 separator '') from t_seq s where s.n <= 160) where d.id in (1000, 3000, 5000);
-- partitions of about 230, 8, 0 and 215 pages: p_low and p_high are 7x above the 32-page parallel threshold, p_mid is 4x below it
create table t_part (id int, grp int, pad varchar(1100)) partition by range (id) (partition p_low values less than (3000), partition p_mid values less than (3100), partition p_gap values less than (3200), partition p_high values less than maxvalue);
insert into t_part select id, grp, sha2(id, 512) || sha2(id + 1, 512) || sha2(id + 2, 512) || sha2(id + 3, 512) || sha2(id + 4, 512) || sha2(id + 5, 512) || sha2(id + 6, 512) || sha2(id + 7, 512) from t_drive where id not between 3100 and 3199;
-- an empty and a one-row table: the copy of the only page, then the end of the scan
create table t_empty (id int, grp int);
create table t_single (id int, grp int);
insert into t_single values (7, 3);
-- a class and its subclass: ALL t_base puts two classes at the outer level
create table t_base (id int, grp int);
create table t_derived under t_base (extra int);
insert into t_base select id, grp from t_drive where id <= 300;
insert into t_derived (id, grp, extra) select id, grp, 0 from t_drive where id between 301 and 700;
-- target of INSERT SELECT
create table t_copy (id int, grp int);
-- db_serial has no MVCC header check: its records are always visible
create serial serial_alpha start with 100 increment by 5;
create serial serial_beta start with 7;
select serial_alpha.next_value, serial_beta.next_value from db_root;
select serial_alpha.next_value from db_root;
update statistics on t_one, t_seq, t_dim, t_drive, t_part, t_empty, t_single, t_copy with fullscan;

set trace on;


evaluate 'Case 1: outer over home, relocated and overflow records, inner index lookup; result = single-table scan';
select /*+ recompile ordered use_nl no_parallel_scan */ d.g as g, count(*) as cnt, sum(a.id) as sum_id, sum(length(a.pad)) as sum_len, sum(a.id * d.w) as sum_w, md5(min(a.pad)) as min_pad, md5(max(a.pad)) as max_pad from t_drive a, t_dim d where d.g = a.grp group by d.g order by 1;
select /*+ recompile no_parallel_scan */ grp as g, count(*) as cnt, sum(id) as sum_id, sum(length(pad)) as sum_len, sum(id * grp * 10) as sum_w, md5(min(pad)) as min_pad, md5(max(pad)) as max_pad from t_drive group by grp order by 1;


evaluate 'Case 2: outer when the inner is a sequential scan, two and three tables; result = the table as the inner side or single-table scan';
select /*+ recompile ordered use_nl no_parallel_scan */ a.grp as g, count(*) as cnt, sum(a.id) as sum_id, sum(length(a.pad)) as sum_len from t_drive a, t_one o group by a.grp order by 1;
select /*+ recompile ordered use_nl no_parallel_scan */ a.grp as g, count(*) as cnt, sum(a.id) as sum_id, sum(length(a.pad)) as sum_len from t_one o, t_drive a group by a.grp order by 1;
select /*+ recompile ordered use_nl no_parallel_scan */ a.grp as g, count(*) as cnt, sum(a.id + o.k + p.k) as sum_id from t_drive a, t_one o, t_one p where o.k = p.k group by a.grp order by 1;
select /*+ recompile no_parallel_scan */ grp as g, count(*) as cnt, sum(id + 2) as sum_id from t_drive group by grp order by 1;


evaluate 'Case 3: parallel outer, buildvalue and mergeable list gathers; result = serial single-table scan';
select /*+ recompile ordered use_nl parallel(4) */ count(*) as cnt, sum(a.id) as sum_id, sum(length(a.pad)) as sum_len, md5(max(a.pad)) as max_pad from t_drive a, t_one o;
show trace;
select /*+ recompile no_parallel_scan */ count(*) as cnt, sum(id) as sum_id, sum(length(pad)) as sum_len, md5(max(pad)) as max_pad from t_drive;
select /*+ recompile ordered use_nl parallel(4) */ a.id as id, a.grp as g, length(a.pad) as len, md5(a.pad) as pad from t_drive a, t_one o where mod(a.id, 250) = 0 order by 1;
show trace;
select /*+ recompile no_parallel_scan */ id as id, grp as g, length(pad) as len, md5(pad) as pad from t_drive where mod(id, 250) = 0 order by 1;


evaluate 'Case 4: correlated subquery, uncorrelated subquery operand and INDEX_CARDINALITY in the select list; result = single-table scan';
select /*+ recompile no_parallel_scan */ a.grp as g, count(*) as cnt, sum((select o.k * a.id from t_one o)) as sum_id from t_drive a group by a.grp order by 1;
select /*+ recompile no_parallel_scan */ grp as g, count(*) as cnt, sum(id) as sum_id from t_drive group by grp order by 1;
select /*+ recompile no_parallel_scan */ a.grp as g, count(*) as cnt, sum(a.id + (select max(k) from t_one)) as sum_id, max(index_cardinality('t_dim', 'pk_t_dim_g', 0)) as card from t_drive a group by a.grp order by 1;
select /*+ recompile no_parallel_scan */ grp as g, count(*) as cnt, sum(id + 1) as sum_id, max(13) as card from t_drive group by grp order by 1;


evaluate 'Case 5: correlated EXISTS subquery; result = single-table scan with the same filter';
select /*+ recompile no_parallel_scan */ a.grp as g, count(*) as cnt, sum(a.id) as sum_id from t_drive a where exists (select 1 from t_one o where o.k = mod(a.id, 3)) group by a.grp order by 1;
select /*+ recompile no_parallel_scan */ grp as g, count(*) as cnt, sum(id) as sum_id from t_drive where mod(id, 3) = 1 group by grp order by 1;


evaluate 'Case 6: subquery in HAVING; result = single-table scan with a constant';
select /*+ recompile no_parallel_scan */ a.grp as g, count(*) as cnt, sum(a.id) as sum_id from t_drive a group by a.grp having count(*) > (select count(*) * 100 from t_one) order by 1;
select /*+ recompile no_parallel_scan */ grp as g, count(*) as cnt, sum(id) as sum_id from t_drive group by grp having count(*) > 100 order by 1;


evaluate 'Case 7: own uncommitted update, relocation, delete and insert; result = single-table scan';
autocommit off;
update t_drive set pad = 'own update' where id between 2001 and 2100;
update t_drive d set pad = (select group_concat(sha2(d.id * 7 + s.n, 512) order by 1 separator '') from t_seq s where s.n <= 24) where d.id between 2101 and 2110;
delete from t_drive where id between 101 and 400;
insert into t_drive select id + 10000, grp, 'own insert' from t_drive where id <= 50;
select /*+ recompile ordered use_nl no_parallel_scan */ a.grp as g, count(*) as cnt, sum(a.id) as sum_id, sum(length(a.pad)) as sum_len from t_drive a, t_one o group by a.grp order by 1;
select /*+ recompile ordered use_nl parallel(4) */ count(*) as cnt, sum(a.id) as sum_id, sum(length(a.pad)) as sum_len from t_drive a, t_one o;
select /*+ recompile no_parallel_scan */ grp as g, count(*) as cnt, sum(id) as sum_id, sum(length(pad)) as sum_len from t_drive group by grp order by 1;
rollback;
autocommit on;


evaluate 'Case 8: partitioned outer, every partition and pruned to the middle ones; result = single-table scan';
select /*+ recompile ordered use_nl no_parallel_scan */ a.grp as g, count(*) as cnt, sum(a.id) as sum_id, sum(length(a.pad)) as sum_len from t_part a, t_one o group by a.grp order by 1;
select /*+ recompile no_parallel_scan */ grp as g, count(*) as cnt, sum(id) as sum_id, sum(length(pad)) as sum_len from t_part group by grp order by 1;
select /*+ recompile ordered use_nl no_parallel_scan */ count(*) as cnt, sum(a.id) as sum_id, min(a.id) as min_id, max(a.id) as max_id from t_part a, t_one o where a.id >= 3000 and a.id < 3200;
select /*+ recompile no_parallel_scan */ count(*) as cnt, sum(id) as sum_id, min(id) as min_id, max(id) as max_id from t_part where id >= 3000 and id < 3200;


evaluate 'Case 9: parallel partitioned outer; result = serial single-table scan';
select /*+ recompile ordered use_nl parallel(4) */ count(*) as cnt, sum(a.id) as sum_id, sum(length(a.pad)) as sum_len from t_part a, t_one o;
show trace;
select /*+ recompile no_parallel_scan */ count(*) as cnt, sum(id) as sum_id, sum(length(pad)) as sum_len from t_part;


evaluate 'Case 10: empty and one-row outer tables; result = single-table scan';
select /*+ recompile ordered use_nl */ count(*) as cnt from t_empty a, t_one o;
select /*+ recompile */ count(*) as cnt from t_empty;
select /*+ recompile ordered use_nl */ a.id as id, a.grp as g from t_single a, t_one o;
select /*+ recompile */ id as id, grp as g from t_single;


evaluate 'Case 11: scan stopped by LIMIT at the first, a middle and the last row';
select /*+ recompile ordered use_nl no_parallel_scan */ a.id as id from t_drive a, t_one o where a.id = 1 limit 1;
select /*+ recompile ordered use_nl no_parallel_scan */ a.id as id from t_drive a, t_one o where a.id = 2999 limit 1;
select /*+ recompile ordered use_nl no_parallel_scan */ a.id as id from t_drive a, t_one o where a.id = 6000 limit 1;


evaluate 'Case 12: class hierarchy as the outer; result = single-table scan';
select /*+ recompile ordered use_nl */ a.grp as g, count(*) as cnt, sum(a.id) as sum_id from all t_base a, t_one o group by a.grp order by 1;
select /*+ recompile */ grp as g, count(*) as cnt, sum(id) as sum_id from all t_base group by grp order by 1;


evaluate 'Case 13: db_serial as the outer; result = single-table read';
select /*+ recompile ordered use_nl */ s.name as name, s.current_val as cur, s.increment_val as inc from db_serial s, t_one o where s.name in ('serial_alpha', 'serial_beta') order by 1;
select /*+ recompile */ name as name, current_val as cur, increment_val as inc from db_serial where name in ('serial_alpha', 'serial_beta') order by 1;


evaluate 'Case 14: INSERT SELECT into the same table and DELETE joined to the outer';
autocommit off;
insert into t_drive (id, grp, pad) select /*+ ordered use_nl no_parallel_scan */ a.id + 20000, a.grp, 'self' from t_drive a, t_one o where a.grp = 13;
select /*+ recompile */ count(*) as cnt, sum(id) as sum_id from t_drive where id > 20000;
insert into t_copy select /*+ ordered use_nl no_parallel_scan */ a.id, a.grp from t_drive a, t_one o where a.grp >= 12 and a.id < 20000;
delete /*+ ordered use_nl no_parallel_scan */ c from t_drive a, t_copy c where a.id = c.id and a.grp = 12;
select /*+ recompile */ grp as g, count(*) as cnt, sum(id) as sum_id from t_copy group by grp order by 1;
rollback;
autocommit on;


evaluate 'Case 15: the same join with FOR UPDATE, which never reads from the copy';
select /*+ recompile ordered use_nl no_parallel_scan */ a.id as id, length(a.pad) as len, md5(a.pad) as pad from t_drive a, t_one o where mod(a.id, 500) = 0 order by 1;
-- trace goes off before the last query that no show trace reads: its plan would stay in the
-- session and the next case's first show trace over a cached plan would print it
set trace off;
select /*+ recompile ordered use_nl no_parallel_scan */ a.id as id, length(a.pad) as len, md5(a.pad) as pad from t_drive a, t_one o where mod(a.id, 500) = 0 order by 1 for update;

set system parameters 'group_concat_max_len=default';
drop serial serial_alpha;
drop serial serial_beta;
drop table t_derived;
drop table t_base;
drop table t_one, t_seq, t_dim, t_drive, t_part, t_empty, t_single, t_copy;
