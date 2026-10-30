/**
 *  This test case verifies CBRD-27703: partition pruning by a DOUBLE value on a BIGINT
 *  LIST, HASH or RANGE partition key returns the rows the same query returns on the
 *  same data in a table without partitions.
 *
 *  Before the fix pruning converted the DOUBLE to the key and kept one partition, while
 *  the row filter compared in DOUBLE and matched both 2^53 and 2^53+1, so the plain table
 *  and the partitioned table differed. A RANGE table even returned only the 2^53+1 row.
 *  With CBRD-27819 the DOUBLE 2^53 equals only the key 2^53 everywhere.
 *
 *  Each query on a partitioned table is followed by the same query on the plain
 *  table t_flat. Both must return the expected rows. Correctness TC.
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
select 'c1an' q, k, v from t_flat where k in (9007199254740992.0e0, 5.0e0) order by 3;
select 'c1ap' q, k, v from t_lst where k in (9007199254740992.0e0, 5.0e0) order by 3;
select 'c1bn' q, k, v from t_flat where k = 9007199254740993.0e0 order by 3;
select 'c1bp' q, k, v from t_lst where k = 9007199254740993.0e0 order by 3;


evaluate 'Case 2: DOUBLE host variables in the IN list';
prepare st_p from 'select ''c2p'' q, k, v from t_lst where k in (?, ?) order by 3';
execute st_p using 9007199254740992.0e0, 5.0e0;
deallocate prepare st_p;
prepare st_n from 'select ''c2n'' q, k, v from t_flat where k in (?, ?) order by 3';
execute st_n using 9007199254740992.0e0, 5.0e0;
deallocate prepare st_n;


evaluate 'Case 3: DOUBLE values built by expressions and SOME';
select 'c3a' q, k, v from t_lst where k = cast(9007199254740992 as double) order by 3;
select 'c3b' q, k, v from t_lst where k = 9007199254740992.0e0 + 0 order by 3;
select 'c3c' q, k, v from t_lst where k = abs(-9007199254740992.0e0) order by 3;
select 'c3d' q, k, v from t_lst where k = some {9007199254740992.0e0, 5.0e0} order by 3;
select 'c3n' q, k, v from t_flat where k = cast(9007199254740992 as double) order by 3;


evaluate 'Case 4: HASH and RANGE tables from the issue comment';
select 'c4a' q, id from t_hsh where b = 9007199254740992e0 order by 1;
select 'c4b' q, id from t_hsh where b + 0 = 9007199254740992e0 order by 1;
select 'c4c' q, id from t_rng where b = 9007199254740992e0 order by 1;
select 'c4d' q, id from t_rng where b >= 9007199254740992e0 and b <= 9007199254740992e0 order by 1;
select 'c4n' q, id from t_hflat where b = 9007199254740992e0 order by 1;

drop table t_lst, t_flat, t_hsh, t_rng, t_hflat;
