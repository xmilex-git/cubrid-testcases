/**
 *  This test case verifies CBRD-27819: a BIGINT or NUMERIC value compared with a DOUBLE
 *  is judged against the DOUBLE comparison value, exactly, at every place that compares them.
 *
 *  Before the fix the common type of the comparison was DOUBLE, so two different values
 *  that round to the same DOUBLE were equal (2^53+1 and 2^53, 17-digit NUMERIC values).
 *  The comparison value of a DOUBLE d is its shortest round-trip decimal when |d| < 2^53,
 *  and the exact integer value of d when |d| >= 2^53. Order uses the same value.
 *
 *  Correctness TC: every query prints the expected literal result. The pre-fix build
 *  fails Cases 1, 2, 4 to 10. Case 3 (CAST keeps its 16-digit truncation) and the
 *  arithmetic result types are unchanged and pass on the pre-fix build too.
 *  Join cases print the plan to show the hash, merge and nested-loop join were used.
 *
 *  Coverage:
 *    Case 1:  constant comparisons of the decision table
 *    Case 2:  values at and above 2^53 (2^54, 2^57, 2^63, 2^80)
 *    Case 3:  CAST and arithmetic result types stay as before
 *    Case 4:  column against column, equality and order
 *    Case 5:  IN list and SOME
 *    Case 6:  CASE, DECODE, NULLIF and IF
 *    Case 7:  nested-loop, hash and sort-merge join on a mixed key
 *    Case 8:  MERGE ON a mixed key
 *    Case 9:  JSON numbers compare by the same rule
 *    Case 10: an equality term copied into another term keeps the comparison value
 */

drop table if exists t_mix, t_tgt, t_eq;

-- Each row puts a BIGINT and a NUMERIC next to a DOUBLE that is equal or differs only beyond DOUBLE precision.
create table t_mix (id int, b bigint, n numeric(38,17), d double);
insert into t_mix values (1, 9007199254740993, 9007199254740993, 9007199254740992e0);
insert into t_mix values (2, 9007199254740992, 9007199254740992, 9007199254740992e0);
insert into t_mix values (3, 0, 0.10000000000000001, 0.1e0);
insert into t_mix values (4, 0, 0.1, 0.1e0);
insert into t_mix values (5, 144115188075855870, 144115188075855870, 144115188075855872e0);
insert into t_mix values (6, 12345678901234568, 12345678901234568, 12345678901234568e0);
-- Two target rows whose BIGINT keys are one apart at 2^53.
create table t_tgt (b bigint, v varchar(10));
insert into t_tgt values (9007199254740993, 'old'), (9007199254740992, 'old');
-- Two NUMERIC(20) and two BIGINT columns holding the same value, for the equality-term copy.
create table t_eq (id int, n numeric(20,0), m numeric(20,0), b bigint, c bigint);
insert into t_eq values (1, 12345678901234568, 12345678901234568, 9007199254740992, 9007199254740992);
update statistics on t_mix, t_tgt, t_eq with fullscan;


evaluate 'Case 1: constant comparisons of the decision table';
select 'c1a' q, 9007199254740993 = 9007199254740992e0, 9007199254740993 > 9007199254740992e0;
select 'c1b' q, cast(0.1 as numeric(10,1)) = 0.1e0, 12345678901234568 = 12345678901234568e0;
select 'c1c' q, 0.10000000000000001 = 0.1e0, 0.10000000000000001 > 0.1e0;
select 'c1d' q, 0.3 = 0.1e0 + 0.2e0;


evaluate 'Case 2: values at and above 2^53';
select 'c2a' q, 144115188075855872 = 144115188075855872e0, 144115188075855870 = 144115188075855872e0, 144115188075855873 = 144115188075855872e0, 144115188075855871 < 144115188075855872e0, 144115188075855873 > 144115188075855872e0;
select 'c2b' q, 18014398509481984 = 18014398509481984e0, 18014398509481985 = 18014398509481984e0;
select 'c2c' q, 9223372036854775807 = 9223372036854775807e0, 9223372036854775807 < 9223372036854775807e0, -9223372036854775808 = -9223372036854775808e0;
select 'c2d' q, cast(1208925819614629174706176 as numeric(38)) = 1208925819614629174706176e0, cast(1208925819614629200000000 as numeric(38)) = 1208925819614629174706176e0;
select 'c2e' q, cast(144115188075855872 as numeric(38)) = 144115188075855872e0, cast(144115188075855870 as numeric(38)) = 144115188075855872e0;


evaluate 'Case 3: CAST and arithmetic result types stay as before';
select 'c3a' q, cast(144115188075855872e0 as numeric(38)), cast(144115188075855872e0 as bigint), cast(144115188075855872e0 as bigint) = 144115188075855872e0;
select 'c3b' q, typeof(b + d), typeof(n + d), typeof(b + n) from t_mix where id = 1;


evaluate 'Case 4: column against column, equality and order';
select 'c4a' q, id from t_mix where b = d order by id;
select 'c4b' q, id from t_mix where n = d order by id;
select 'c4c' q, id from t_mix where b < d order by id;
select 'c4d' q, id from t_mix where n > d order by id;
select 'c4e' q, id from t_mix where d >= n order by id;


evaluate 'Case 5: IN list and SOME';
select 'c5a' q, id from t_mix where b in (9007199254740992e0, 144115188075855872e0) order by id;
select 'c5b' q, id from t_mix where n in (0.1e0, 12345678901234568e0) order by id;
select 'c5c' q, id from t_mix where b = some {9007199254740992e0, 144115188075855872e0} order by id;
select 'c5d' q, id from t_mix where n in (select d from t_mix where id in (1, 3)) order by id;


evaluate 'Case 6: CASE, DECODE, NULLIF and IF';
select 'c6a' q, id, case b when 9007199254740992e0 then 'eq' else 'ne' end, decode(n, 0.1e0, 'eq', 'ne') from t_mix order by id;
select 'c6b' q, id, nullif(b, d) is null, nullif(n, d) is null, if(b = d, 'eq', 'ne') from t_mix order by id;


evaluate 'Case 7: nested-loop, hash and sort-merge join on a mixed key';
--@queryplan
select /*+ recompile use_nl ordered */ 'c7a' q, x.id, y.id from t_mix x, t_mix y where x.b = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_hash ordered */ 'c7b' q, x.id, y.id from t_mix x, t_mix y where x.b = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_merge ordered */ 'c7c' q, x.id, y.id from t_mix x, t_mix y where x.b = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_nl ordered */ 'c7d' q, x.id, y.id from t_mix x, t_mix y where x.n = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_hash ordered */ 'c7e' q, x.id, y.id from t_mix x, t_mix y where x.n = y.d order by 2, 3;
--@queryplan
select /*+ recompile use_merge ordered */ 'c7f' q, x.id, y.id from t_mix x, t_mix y where x.n = y.d order by 2, 3;


evaluate 'Case 8: MERGE ON a mixed key';
merge into t_tgt t using (select d from t_mix where id = 1) s on (t.b = s.d) when matched then update set t.v = 'matched';
select 'c8a' q, b, v from t_tgt order by b;


evaluate 'Case 9: JSON numbers compare by the same rule';
select 'c9a' q, id from t_mix where cast(b as json) = cast(d as json) order by id;
select 'c9b' q, cast(cast(9007199254740993 as bigint) as json) = cast(9007199254740992e0 as json);


evaluate 'Case 10: an equality term copied into another term keeps the comparison value';
select 'c10a' q, id, n from t_eq where n = 12345678901234568e0 and m = n order by id;
select 'c10b' q, id from t_eq where n = 12345678901234568e0 order by id;
select 'c10c' q, id from t_eq where m = n order by id;
select 'c10d' q, id, b from t_eq where b = 9007199254740992e0 and c = b order by id;

drop table t_mix, t_tgt, t_eq;
