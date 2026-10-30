/**
 *  This test case verifies CBRD-27819: a BIGINT, INTEGER or NUMERIC value compared with
 *  a DOUBLE or FLOAT gives the same rows on every access path: index range scan,
 *  multi-column index, partition pruning, UPDATE and DELETE on a partitioned table,
 *  and nested-loop, hash and sort-merge join.
 *
 *  The comparison is done in DOUBLE (in FLOAT against a FLOAT), the same as before:
 *  9007199254740993 = 9007199254740992e0 is true. Before the fix RANGE and LIST
 *  pruning converted the DOUBLE to the key type and kept one partition, so SELECT,
 *  UPDATE and DELETE missed rows of the other partition (Case 5), and an equality
 *  term copied into another term changed the rows (Case 8). Cases 1 to 4 and 6 hold
 *  on the pre-fix build too and guard the index and join paths near 2^53, at 17-digit
 *  NUMERIC values, at non-integer DOUBLE values and near FLOAT 2^24.
 *
 *  Every query is a pair or a group with the same label prefix. The label ending in
 *  n is the reference: USING INDEX NONE, a table without partitions, or a nested-loop
 *  join. The other members (i index, p RANGE, q LIST, r HASH partition, h hash
 *  join, m merge join, e the same query on the heap) must return the rows of the
 *  reference. Index members print the plan (iscan).
 *  Case 7 prints values the NUMERIC changes of this issue must not change.
 *
 *  Coverage:
 *    Case 1:  BIGINT index, equality and ranges near 2^53 and 2^57
 *    Case 2:  BIGINT index, non-integer and out-of-range DOUBLE bounds
 *    Case 3:  NUMERIC index, 17-digit values and non-integer DOUBLE values
 *    Case 4:  INTEGER, BIGINT and NUMERIC index against FLOAT near 2^24
 *    Case 5:  RANGE, LIST and HASH partitions against the plain table, UPDATE and DELETE
 *    Case 6:  nested-loop, hash and sort-merge join on a mixed key
 *    Case 7:  NUMERIC results that stay as before (CAST, arithmetic, BIGINT x NUMERIC)
 */

drop table if exists t_big, t_num, t_wide, t_flt, t_rng, t_lst, t_hsh, t_flat, t_mix, t_eq;

-- BIGINT keys at 2^53-1 .. 2^53+2, around 2^57, at both ends of BIGINT, and small integers.
create table t_big (id int, b bigint);
insert into t_big values (1, 0), (2, 1), (3, 2), (4, 3), (5, 9007199254740991), (6, 9007199254740992), (7, 9007199254740993), (8, 9007199254740994), (9, 144115188075855870), (10, 144115188075855872), (11, 144115188075855873), (12, 9223372036854775807), (13, -9223372036854775808);
create index i_big_b on t_big (b);
-- NUMERIC(10,2) keys near 0.3, and NUMERIC(38) keys with 17 digits and around 2^57.
create table t_num (id int, n numeric(10,2));
insert into t_num values (1, 0.10), (2, 0.20), (3, 0.30), (4, 0.31), (5, 99999999.99);
create index i_num_n on t_num (n);
create table t_wide (id int, n numeric(38,0));
insert into t_wide values (1, 12345678901234567), (2, 12345678901234568), (3, 12345678901234569), (4, 144115188075855870), (5, 144115188075855872), (6, 144115188075855873);
create index i_wide_n on t_wide (n);
-- INTEGER, BIGINT and NUMERIC keys next to FLOAT 2^24 and FLOAT 0.3.
create table t_flt (id int, i int, b bigint, n numeric(12,10));
insert into t_flt values (1, 16777215, 16777215, 0.2999999821), (2, 16777216, 16777216, 0.3000000000), (3, 16777217, 16777217, 0.3000000119), (4, 16777218, 16777218, 0.3000000300);
create index i_flt_i on t_flt (i);
create index i_flt_b on t_flt (b);
create index i_flt_n on t_flt (n);
-- RANGE split at 2^53+1 and at 10, LIST one key per partition, HASH, and the plain twin of all three.
create table t_rng (k bigint, v int) partition by range (k) (partition p_lo values less than (10), partition p_mid values less than (9007199254740993), partition p_hi values less than maxvalue);
create table t_lst (k bigint, v int) partition by list (k) (partition q_a values in (9007199254740992), partition q_b values in (9007199254740993), partition q_c values in (9007199254740994), partition q_d values in (9), partition q_e values in (10), partition q_f values in (11));
create table t_hsh (k bigint, v int) partition by hash (k) partitions 4;
create table t_flat (k bigint, v int);
insert into t_rng values (9, 1), (10, 2), (11, 3), (9007199254740992, 4), (9007199254740993, 5), (9007199254740994, 6);
insert into t_lst select * from t_rng;
insert into t_hsh select * from t_rng;
insert into t_flat select * from t_rng;
-- Join input: BIGINT and NUMERIC next to a DOUBLE that is equal to them only in DOUBLE.
create table t_mix (id int, b bigint, n numeric(38,0), d double);
insert into t_mix values (1, 9007199254740993, 12345678901234567, 9007199254740992e0), (2, 9007199254740992, 12345678901234568, 12345678901234568e0), (3, 5, 5, 5.5e0);
-- b of rows 1 and 2 equals 2^53 only in DOUBLE, c = b holds only in row 2; n = m holds in row 1 with 17 digits.
create table t_eq (id int, b bigint, c bigint, n numeric(20,0), m numeric(20,0));
insert into t_eq values (1, 9007199254740992, 9007199254740993, 12345678901234568, 12345678901234568), (2, 9007199254740993, 9007199254740993, 1, 1), (3, 5, 5, 5, 5);
create index i_eq_b on t_eq (b);
create index i_eq_n on t_eq (n);
update statistics on t_big, t_num, t_wide, t_flt, t_rng, t_lst, t_hsh, t_flat, t_mix, t_eq with fullscan;


evaluate 'Case 1: BIGINT index, equality and ranges near 2^53 and 2^57';
--@queryplan
select /*+ recompile */ 'c1ai' q, b from t_big force index (i_big_b) where b = 9007199254740992e0 order by b;
select /*+ recompile */ 'c1an' q, b from t_big where b = 9007199254740992e0 using index none order by b;
--@queryplan
select /*+ recompile */ 'c1bi' q, b from t_big force index (i_big_b) where b = 9007199254740994e0 order by b;
select /*+ recompile */ 'c1bn' q, b from t_big where b = 9007199254740994e0 using index none order by b;
--@queryplan
select /*+ recompile */ 'c1ci' q, b from t_big force index (i_big_b) where b > 9007199254740992e0 and b < 9007199254741000 order by b;
select /*+ recompile */ 'c1cn' q, b from t_big where b > 9007199254740992e0 and b < 9007199254741000 using index none order by b;
--@queryplan
select /*+ recompile */ 'c1di' q, b from t_big force index (i_big_b) where b >= 9007199254740992e0 and b < 9007199254741000 order by b;
select /*+ recompile */ 'c1dn' q, b from t_big where b >= 9007199254740992e0 and b < 9007199254741000 using index none order by b;
--@queryplan
select /*+ recompile */ 'c1ei' q, b from t_big force index (i_big_b) where b < 9007199254740992e0 and b > 3 order by b;
select /*+ recompile */ 'c1en' q, b from t_big where b < 9007199254740992e0 and b > 3 using index none order by b;
--@queryplan
select /*+ recompile */ 'c1fi' q, b from t_big force index (i_big_b) where b = 144115188075855872e0 order by b;
select /*+ recompile */ 'c1fn' q, b from t_big where b = 144115188075855872e0 using index none order by b;
--@queryplan
select /*+ recompile */ 'c1gi' q, b from t_big force index (i_big_b) where b in (9007199254740992e0, 144115188075855872e0) order by b;
select /*+ recompile */ 'c1gn' q, b from t_big where b in (9007199254740992e0, 144115188075855872e0) using index none order by b;
prepare st_i from 'select /*+ recompile */ ? q, b from t_big force index (i_big_b) where b > ? and b <= ? order by b';
prepare st_n from 'select /*+ recompile */ ? q, b from t_big where b > ? and b <= ? using index none order by b';
execute st_i using 'c1hi', 9007199254740992e0, 9007199254740994;
execute st_n using 'c1hn', 9007199254740992e0, 9007199254740994;
execute st_i using 'c1ii', 9007199254740991, 9007199254740992e0;
execute st_n using 'c1in', 9007199254740991, 9007199254740992e0;
deallocate prepare st_i;
deallocate prepare st_n;


evaluate 'Case 2: BIGINT index, non-integer and out-of-range DOUBLE bounds';
--@queryplan
select /*+ recompile */ 'c2ai' q, b from t_big force index (i_big_b) where b between 0.5e0 and 2.5e0 order by b;
select /*+ recompile */ 'c2an' q, b from t_big where b between 0.5e0 and 2.5e0 using index none order by b;
--@queryplan
select /*+ recompile */ 'c2bi' q, count(*) from t_big force index (i_big_b) where b = 1.5e0;
select /*+ recompile */ 'c2bn' q, count(*) from t_big where b = 1.5e0 using index none;
--@queryplan
select /*+ recompile */ 'c2ci' q, count(*) from t_big force index (i_big_b) where b <= 1e20;
select /*+ recompile */ 'c2cn' q, count(*) from t_big where b <= 1e20 using index none;
--@queryplan
select /*+ recompile */ 'c2di' q, count(*) from t_big force index (i_big_b) where b >= 9223372036854775807e0;
select /*+ recompile */ 'c2dn' q, count(*) from t_big where b >= 9223372036854775807e0 using index none;
--@queryplan
select /*+ recompile */ 'c2ei' q, count(*) from t_big force index (i_big_b) where b < 9223372036854775807e0;
select /*+ recompile */ 'c2en' q, count(*) from t_big where b < 9223372036854775807e0 using index none;
--@queryplan
select /*+ recompile */ 'c2fi' q, count(*) from t_big force index (i_big_b) where b <= -9223372036854775808e0;
select /*+ recompile */ 'c2fn' q, count(*) from t_big where b <= -9223372036854775808e0 using index none;


evaluate 'Case 3: NUMERIC index, 17-digit values and non-integer DOUBLE values';
--@queryplan
select /*+ recompile */ 'c3ai' q, id from t_wide force index (i_wide_n) where n = 12345678901234568e0 order by id;
select /*+ recompile */ 'c3an' q, id from t_wide where n = 12345678901234568e0 using index none order by id;
--@queryplan
select /*+ recompile */ 'c3bi' q, count(*) from t_wide force index (i_wide_n) where n > 12345678901234568e0 and n < 20000000000000000;
select /*+ recompile */ 'c3bn' q, count(*) from t_wide where n > 12345678901234568e0 and n < 20000000000000000 using index none;
--@queryplan
select /*+ recompile */ 'c3ci' q, id from t_wide force index (i_wide_n) where n = 144115188075855872e0 order by id;
select /*+ recompile */ 'c3cn' q, id from t_wide where n = 144115188075855872e0 using index none order by id;
--@queryplan
select /*+ recompile */ 'c3di' q, count(*) from t_num force index (i_num_n) where n = 0.1e0 + 0.2e0;
select /*+ recompile */ 'c3dn' q, count(*) from t_num where n = 0.1e0 + 0.2e0 using index none;
--@queryplan
select /*+ recompile */ 'c3ei' q, id from t_num force index (i_num_n) where n < 0.30000000000000004e0 order by id;
select /*+ recompile */ 'c3en' q, id from t_num where n < 0.30000000000000004e0 using index none order by id;
--@queryplan
select /*+ recompile */ 'c3fi' q, id from t_num force index (i_num_n) where n = 0.3e0 order by id;
select /*+ recompile */ 'c3fn' q, id from t_num where n = 0.3e0 using index none order by id;
--@queryplan
select /*+ recompile */ 'c3gi' q, id from t_num force index (i_num_n) where n > 0.305e0 order by id;
select /*+ recompile */ 'c3gn' q, id from t_num where n > 0.305e0 using index none order by id;
--@queryplan
select /*+ recompile */ 'c3hi' q, count(*) from t_num force index (i_num_n) where n <= 1e20;
select /*+ recompile */ 'c3hn' q, count(*) from t_num where n <= 1e20 using index none;


evaluate 'Case 4: INTEGER, BIGINT and NUMERIC index against FLOAT near 2^24';
--@queryplan
select /*+ recompile */ 'c4ai' q, id from t_flt force index (i_flt_i) where i = cast(16777216 as float) order by id;
select /*+ recompile */ 'c4an' q, id from t_flt where i = cast(16777216 as float) using index none order by id;
--@queryplan
select /*+ recompile */ 'c4bi' q, id from t_flt force index (i_flt_b) where b = cast(16777216 as float) order by id;
select /*+ recompile */ 'c4bn' q, id from t_flt where b = cast(16777216 as float) using index none order by id;
--@queryplan
select /*+ recompile */ 'c4ci' q, id from t_flt force index (i_flt_i) where i > cast(16777216 as float) order by id;
select /*+ recompile */ 'c4cn' q, id from t_flt where i > cast(16777216 as float) using index none order by id;
--@queryplan
select /*+ recompile */ 'c4di' q, id from t_flt force index (i_flt_n) where n = cast(0.3 as float) order by id;
select /*+ recompile */ 'c4dn' q, id from t_flt where n = cast(0.3 as float) using index none order by id;
--@queryplan
select /*+ recompile */ 'c4ei' q, id from t_flt force index (i_flt_n) where n > cast(0.3 as float) order by id;
select /*+ recompile */ 'c4en' q, id from t_flt where n > cast(0.3 as float) using index none order by id;


evaluate 'Case 5: RANGE, LIST and HASH partitions against the plain table, UPDATE and DELETE';
select 'c5ap' q, k, v from t_rng where k = 9007199254740992e0 order by v;
select 'c5aq' q, k, v from t_lst where k = 9007199254740992e0 order by v;
select 'c5ar' q, k, v from t_hsh where k = 9007199254740992e0 order by v;
select 'c5an' q, k, v from t_flat where k = 9007199254740992e0 order by v;
select 'c5bp' q, k, v from t_rng where k >= 9007199254740993e0 order by v;
select 'c5bq' q, k, v from t_lst where k >= 9007199254740993e0 order by v;
select 'c5bn' q, k, v from t_flat where k >= 9007199254740993e0 order by v;
select 'c5cp' q, k, v from t_rng where k < 9007199254740993e0 order by v;
select 'c5cq' q, k, v from t_lst where k < 9007199254740993e0 order by v;
select 'c5cn' q, k, v from t_flat where k < 9007199254740993e0 order by v;
select 'c5dp' q, k, v from t_rng where k < 9.5e0 order by v;
select 'c5dn' q, k, v from t_flat where k < 9.5e0 order by v;
select 'c5eq' q, k, v from t_lst where k in (9.5e0, 10e0, 10.5e0) order by v;
select 'c5en' q, k, v from t_flat where k in (9.5e0, 10e0, 10.5e0) order by v;
select 'c5fp' q, k, v from t_rng where k between 9.5e0 and 10.5e0 order by v;
select 'c5fn' q, k, v from t_flat where k between 9.5e0 and 10.5e0 order by v;
select 'c5gr' q, k, v from t_hsh where k = 10e0 or k = 9.5e0 order by v;
select 'c5gn' q, k, v from t_flat where k = 10e0 or k = 9.5e0 order by v;
select 'c5hr' q, k, v from t_hsh where k in (9007199254740994e0, 11e0) order by v;
select 'c5hn' q, k, v from t_flat where k in (9007199254740994e0, 11e0) order by v;
update t_rng set v = v + 100 where k = 9007199254740992e0;
update t_lst set v = v + 100 where k = 9007199254740992e0;
update t_hsh set v = v + 100 where k = 9007199254740992e0;
update t_flat set v = v + 100 where k = 9007199254740992e0;
select 'c5ip' q, k, v from t_rng order by k, v;
select 'c5iq' q, k, v from t_lst order by k, v;
select 'c5ir' q, k, v from t_hsh order by k, v;
select 'c5in' q, k, v from t_flat order by k, v;
delete from t_rng where k = 9007199254740993e0;
delete from t_lst where k = 9007199254740993e0;
delete from t_hsh where k = 9007199254740993e0;
delete from t_flat where k = 9007199254740993e0;
select 'c5jp' q, k from t_rng order by k;
select 'c5jq' q, k from t_lst order by k;
select 'c5jr' q, k from t_hsh order by k;
select 'c5jn' q, k from t_flat order by k;


evaluate 'Case 6: nested-loop, hash and sort-merge join on a mixed key';
--@queryplan
select /*+ recompile use_nl ordered */ 'c6an' q, x.id, y.id from t_mix x, t_mix y where x.b = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_hash ordered */ 'c6ah' q, x.id, y.id from t_mix x, t_mix y where x.b = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_merge ordered */ 'c6am' q, x.id, y.id from t_mix x, t_mix y where x.b = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_nl ordered */ 'c6bn' q, x.id, y.id from t_mix x, t_mix y where x.n = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_hash ordered */ 'c6bh' q, x.id, y.id from t_mix x, t_mix y where x.n = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_merge ordered */ 'c6bm' q, x.id, y.id from t_mix x, t_mix y where x.n = y.d order by 2, 3;


evaluate 'Case 7: NUMERIC results that stay as before (CAST, arithmetic, BIGINT x NUMERIC)';
select 'c7a' q, cast(12345678901234568e0 as numeric(38)), cast(0.1e0 as numeric(20,18)), cast(144115188075855872e0 as numeric(38)), cast(1.5e0 as numeric(5,0));
select 'c7b' q, cast(9007199254740993 as bigint) = cast(9007199254740993 as numeric(20)), cast(9007199254740993 as bigint) = cast(9007199254740992 as numeric(20)), cast(5 as int) < cast(5.01 as numeric(5,2));
select 'c7c' q, cast(12345678901234567 as numeric(38)) + 1, cast(1.25 as numeric(5,2)) * cast(3 as bigint), cast(10 as numeric(10)) / 3, typeof(cast(1 as numeric(5,2)) + 1e0);
select 'c7d' q, n, count(*) from (select n from t_wide union all select n from t_wide) x group by n order by n;



evaluate 'Case 8: an equality term copied into another term (col = const and col2 = col)';
-- The reference writes the column as b + 0 (n + 0) in both terms, so the constant is
-- not copied into the other term and each row is compared as written.
--@queryplan
select /*+ recompile */ 'c8ai' q, id from t_eq force index (i_eq_b) where b = 9007199254740992e0 and c = b order by id;
select /*+ recompile */ 'c8ae' q, id from t_eq where b = 9007199254740992e0 and c = b using index none order by id;
select /*+ recompile */ 'c8an' q, id from t_eq where b + 0 = 9007199254740992e0 and c = b + 0 using index none order by id;
--@queryplan
select /*+ recompile */ 'c8bi' q, count(*) from t_eq force index (i_eq_n) where n = 12345678901234568e0 and m = n;
select /*+ recompile */ 'c8be' q, count(*) from t_eq where n = 12345678901234568e0 and m = n using index none;
select /*+ recompile */ 'c8bn' q, count(*) from t_eq where n + 0 = 12345678901234568e0 and m = n + 0 using index none;

drop table t_big, t_num, t_wide, t_flt, t_rng, t_lst, t_hsh, t_flat, t_mix, t_eq;
