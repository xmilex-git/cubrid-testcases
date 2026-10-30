/**
 *  This test case verifies CBRD-27703: a query with a DOUBLE value on a BIGINT LIST,
 *  HASH or RANGE partition key returns the rows the same query returns on the same
 *  data in a table without partitions.
 *
 *  A BIGINT compared with a DOUBLE is compared in DOUBLE, so the DOUBLE 2^53 equals
 *  both 2^53 and 2^53+1. Before the fix pruning converted the DOUBLE to the key type
 *  and kept only the partition of 2^53 (a RANGE table even kept only the partition
 *  of 2^53+1), so the partitioned table returned fewer rows than the plain table.
 *
 *  Each query on a partitioned table (label q ends in p) is paired with the same
 *  query on the plain table t_flat (label ends in n). The expected rows of both
 *  are the rows of the plain table. Correctness TC.
 *
 *  Coverage:
 *    Case 1:  the issue repro on LIST, IN list and equality
 *    Case 2:  DOUBLE host variables in the IN list
 *    Case 3:  DOUBLE values built by expressions and SOME
 *    Case 4:  HASH and RANGE tables from the issue comment
 */

drop table if exists t_lst, t_flat, t_hsh, t_rng, t_hflat;

-- One LIST partition per key, so a pruned partition loses exactly its row.
create table t_lst (k bigint, v int) partition by list (k) (partition p_a values in (9007199254740992), partition p_b values in (9007199254740993), partition p_c values in (5));
insert into t_lst values (9007199254740992, 1), (9007199254740993, 2), (5, 3);
-- The same rows without partitions.
create table t_flat (k bigint, v int);
insert into t_flat values (9007199254740992, 1), (9007199254740993, 2), (5, 3);
-- HASH and RANGE tables of the issue comment, and their plain twin.
create table t_hsh (id int, b bigint) partition by hash (b) partitions 7;
insert into t_hsh values (1, 9007199254740992), (2, 9007199254740993), (3, 9007199254740994), (4, 0);
create table t_rng (id int, b bigint) partition by range (b) (partition p_lo values less than (9007199254740993), partition p_hi values less than maxvalue);
insert into t_rng values (1, 9007199254740992), (2, 9007199254740993), (3, 9007199254740994), (4, 0);
create table t_hflat (id int, b bigint);
insert into t_hflat values (1, 9007199254740992), (2, 9007199254740993), (3, 9007199254740994), (4, 0);
update statistics on t_lst, t_flat, t_hsh, t_rng, t_hflat with fullscan;


evaluate 'Case 1: the issue repro on LIST, IN list and equality';
select 'c1ap' q, k, v from t_lst where k in (9007199254740992.0e0, 5.0e0) order by 3;
select 'c1an' q, k, v from t_flat where k in (9007199254740992.0e0, 5.0e0) order by 3;
select 'c1bp' q, k, v from t_lst where k = 9007199254740993.0e0 order by 3;
select 'c1bn' q, k, v from t_flat where k = 9007199254740993.0e0 order by 3;


evaluate 'Case 2: DOUBLE host variables in the IN list';
prepare st_p from 'select ? q, k, v from t_lst where k in (?, ?) order by 3';
prepare st_n from 'select ? q, k, v from t_flat where k in (?, ?) order by 3';
execute st_p using 'c2ap', 9007199254740992.0e0, 5.0e0;
execute st_n using 'c2an', 9007199254740992.0e0, 5.0e0;
deallocate prepare st_p;
deallocate prepare st_n;


evaluate 'Case 3: DOUBLE values built by expressions and SOME';
select 'c3ap' q, k, v from t_lst where k = cast(9007199254740992 as double) order by 3;
select 'c3an' q, k, v from t_flat where k = cast(9007199254740992 as double) order by 3;
select 'c3bp' q, k, v from t_lst where k = 9007199254740992.0e0 + 0 order by 3;
select 'c3bn' q, k, v from t_flat where k = 9007199254740992.0e0 + 0 order by 3;
select 'c3cp' q, k, v from t_lst where k = abs(-9007199254740992.0e0) order by 3;
select 'c3cn' q, k, v from t_flat where k = abs(-9007199254740992.0e0) order by 3;
select 'c3dp' q, k, v from t_lst where k = some {9007199254740992.0e0, 5.0e0} order by 3;
select 'c3dn' q, k, v from t_flat where k = some {9007199254740992.0e0, 5.0e0} order by 3;


evaluate 'Case 4: HASH and RANGE tables from the issue comment';
select 'c4ap' q, id from t_hsh where b = 9007199254740992e0 order by 1;
select 'c4an' q, id from t_hflat where b = 9007199254740992e0 order by 1;
select 'c4bp' q, id from t_hsh where b + 0 = 9007199254740992e0 order by 1;
select 'c4bn' q, id from t_hflat where b + 0 = 9007199254740992e0 order by 1;
select 'c4cp' q, id from t_rng where b = 9007199254740992e0 order by 1;
select 'c4cn' q, id from t_hflat where b = 9007199254740992e0 order by 1;
select 'c4dp' q, id from t_rng where b >= 9007199254740992e0 and b <= 9007199254740992e0 order by 1;
select 'c4dn' q, id from t_hflat where b >= 9007199254740992e0 and b <= 9007199254740992e0 order by 1;

drop table t_lst, t_flat, t_hsh, t_rng, t_hflat;
