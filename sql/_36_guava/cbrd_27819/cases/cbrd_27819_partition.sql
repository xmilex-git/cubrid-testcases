/**
 *  This test case verifies CBRD-27819: partition pruning and the target rows of
 *  UPDATE and DELETE on a BIGINT partition key compared with a DOUBLE follow the
 *  DOUBLE comparison value, and INSERT and UPDATE SET keep the assignment rounding.
 *
 *  Before the fix pruning converted the DOUBLE to the key type and the row filter
 *  compared in DOUBLE, so a RANGE, LIST or HASH table returned other rows than the
 *  same data in a plain table, and DELETE removed only some of the rows its WHERE took.
 *
 *  Each select on a partitioned table is followed by the same select on a plain
 *  table with the same rows (t_flat), and both must give the expected rows.
 *  Row placement after INSERT and UPDATE SET is read from the partition tables.
 *
 *  Coverage:
 *    Case 1:  RANGE with fractional DOUBLE bounds
 *    Case 2:  RANGE split at 2^53+1
 *    Case 3:  LIST at 2^53 and 2^53+1, IN list with fractional values
 *    Case 4:  HASH at 2^53 and a fractional value
 *    Case 5:  INSERT and UPDATE SET round the DOUBLE and route by the result
 *    Case 6:  UPDATE and DELETE target rows by the comparison value
 */

drop table if exists t_rng, t_big, t_lst, t_hsh, t_flat;

-- RANGE on small integers for fractional bounds.
create table t_rng (k bigint, v int) partition by range (k) (partition p_lo values less than (10), partition p_mid values less than (20), partition p_hi values less than maxvalue);
insert into t_rng values (5, 1), (9, 2), (10, 3), (11, 4), (19, 5), (20, 6), (25, 7);
-- RANGE split between 2^53 and 2^53+1.
create table t_big (k bigint, v int) partition by range (k) (partition p_lo values less than (9007199254740993), partition p_hi values less than maxvalue);
insert into t_big values (9007199254740992, 1), (9007199254740993, 2), (9007199254740994, 3);
-- LIST with one partition per key.
create table t_lst (k bigint, v int) partition by list (k) (partition q_a values in (9007199254740992), partition q_b values in (9007199254740993), partition q_c values in (1), partition q_d values in (2), partition q_e values in (3));
insert into t_lst values (9007199254740992, 1), (9007199254740993, 2), (1, 3), (2, 4), (3, 5);
-- HASH over the same keys plus small ones.
create table t_hsh (k bigint, v int) partition by hash (k) partitions 4;
insert into t_hsh values (9007199254740992, 1), (9007199254740993, 2), (5, 3), (6, 4);
-- The plain twin of t_big and t_lst.
create table t_flat (k bigint, v int);
insert into t_flat values (9007199254740992, 1), (9007199254740993, 2), (9007199254740994, 3), (1, 3), (2, 4), (3, 5);
update statistics on t_rng, t_big, t_lst, t_hsh, t_flat with fullscan;


evaluate 'Case 1: RANGE with fractional DOUBLE bounds';
select 'c1a' q, k from t_rng where k = 9.5e0 order by k;
select 'c1b' q, k from t_rng where k < 9.5e0 order by k;
select 'c1c' q, k from t_rng where k < 10.5e0 order by k;
select 'c1d' q, k from t_rng where k between 9.5e0 and 19.5e0 order by k;
select 'c1e' q, k from t_rng where k = 10e0 order by k;
select 'c1f' q, count(*) from t_rng where k <= 1e20;


evaluate 'Case 2: RANGE split at 2^53+1';
select 'c2a' q, k, v from t_big where k = 9007199254740993e0 order by v;
select 'c2an' q, k, v from t_flat where k = 9007199254740993e0 and v < 3 order by v;
select 'c2b' q, k, v from t_big where k >= 9007199254740993e0 order by v;
select 'c2c' q, k, v from t_big where k < 9007199254740993e0 order by v;
select 'c2d' q, k, v from t_big where k > 9007199254740992e0 order by v;
select 'c2e' q, k, v from t_big where k = 9007199254740992e0 order by v;
select 'c2f' q, k, v from t_big where k between 9007199254740992e0 and 9007199254740992e0 order by v;


evaluate 'Case 3: LIST at 2^53 and 2^53+1, IN list with fractional values';
select 'c3a' q, k, v from t_lst where k = 9007199254740993e0 order by v;
select 'c3b' q, k, v from t_lst where k = 9007199254740992e0 order by v;
select 'c3bn' q, k, v from t_flat where k = 9007199254740992e0 order by v;
select 'c3c' q, k, v from t_lst where k in (9007199254740992e0, 1e0) order by v;
select 'c3d' q, count(*) from t_lst where k = 1.5e0;
select 'c3e' q, k from t_lst where k < 2.5e0 order by k;
select 'c3f' q, k from t_lst where k in (1.5e0, 2e0, 3.0000000000000004e0) order by k;


evaluate 'Case 4: HASH at 2^53 and a fractional value';
select 'c4a' q, k, v from t_hsh where k = 9007199254740992e0 order by v;
select 'c4b' q, k, v from t_hsh where k + 0 = 9007199254740992e0 order by v;
select 'c4c' q, k, v from t_hsh where k = 5.5e0 order by v;
select 'c4d' q, k, v from t_hsh where k in (9007199254740993e0, 5e0) order by v;


evaluate 'Case 5: INSERT and UPDATE SET round the DOUBLE and route by the result';
insert into t_rng values (9.5e0, 100);
insert into t_rng values (19.5e0, 101);
select 'c5a' q, 'p_lo' p, k, v from t_rng__p__p_lo where v >= 100 union all select 'c5a', 'p_mid', k, v from t_rng__p__p_mid where v >= 100 union all select 'c5a', 'p_hi', k, v from t_rng__p__p_hi where v >= 100 order by 4;
update t_rng set k = 9.4e0 where v = 101;
select 'c5b' q, 'p_lo' p, k, v from t_rng__p__p_lo where v >= 100 union all select 'c5b', 'p_mid', k, v from t_rng__p__p_mid where v >= 100 union all select 'c5b', 'p_hi', k, v from t_rng__p__p_hi where v >= 100 order by 4;
insert into t_big values (9007199254740993e0, 10);
select 'c5c' q, 'p_lo' p, k, v from t_big__p__p_lo where v = 10 union all select 'c5c', 'p_hi', k, v from t_big__p__p_hi where v = 10 order by 4;


evaluate 'Case 6: UPDATE and DELETE target rows by the comparison value';
update t_rng set v = v + 1000 where k = 9.5e0;
select 'c6a' q, count(*) from t_rng where v >= 1000;
update t_big set v = v + 1000 where k = 9007199254740993e0 and v < 10;
select 'c6b' q, k, v from t_big order by k, v;
delete from t_big where k = 9007199254740993e0;
select 'c6c' q, k, v from t_big order by k, v;
delete from t_lst where k = 9007199254740993e0;
select 'c6d' q, k, v from t_lst order by v;

drop table t_rng, t_big, t_lst, t_hsh, t_flat;
