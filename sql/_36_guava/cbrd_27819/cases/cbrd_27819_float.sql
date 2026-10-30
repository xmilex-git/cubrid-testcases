/**
 *  This test case verifies CBRD-27819: a NUMERIC compared with a FLOAT is judged against
 *  the shortest decimal of the float32 value, and an INTEGER or BIGINT compared with a
 *  FLOAT is compared after widening the FLOAT to DOUBLE.
 *
 *  Before the fix both comparisons ran in FLOAT, so NUMERIC 0.3000000119 equaled the
 *  float 0.3 and INTEGER 16777217 equaled the float 16777216. The comparison value of
 *  the float 0.3 is 0.3, not the widened DOUBLE 0.30000001192092896.
 *
 *  Correctness TC: expected literal results. Index queries run with FORCE INDEX and
 *  USING INDEX NONE, plan printed. Result types of FLOAT arithmetic are printed as a
 *  control that does not change.
 *
 *  Coverage:
 *    Case 1:  NUMERIC column against FLOAT column
 *    Case 2:  NUMERIC constants against a FLOAT
 *    Case 3:  INTEGER and BIGINT against FLOAT 16777216
 *    Case 4:  index ranges on NUMERIC, INTEGER and BIGINT keys by a FLOAT
 *    Case 5:  result types stay as before
 */

drop table if exists t_flt;

-- FLOAT 0.3 next to NUMERIC values on both sides of its float32 value, and FLOAT 16777216 next to 2^24 and 2^24+1.
create table t_flt (id int, f float, n numeric(12,10), i int, b bigint);
insert into t_flt values (1, 0.3, 0.3000000119, 16777217, 16777217);
insert into t_flt values (2, 0.3, 0.3000000000, 16777216, 16777216);
insert into t_flt values (3, 16777216, 0.3000000100, 0, 144115188075855872);
create index i_flt_n on t_flt (n);
create index i_flt_i on t_flt (i);
create index i_flt_b on t_flt (b);
update statistics on t_flt with fullscan;


evaluate 'Case 1: NUMERIC column against FLOAT column';
select 'c1a' q, id, f = n, n = f, n > f, n < f from t_flt order by id;


evaluate 'Case 2: NUMERIC constants against a FLOAT';
select 'c2a' q, id, f = 0.3, f = cast(0.3000000119 as numeric(12,10)), f < cast(0.3000000119 as numeric(12,10)) from t_flt where id in (1, 2) order by id;


evaluate 'Case 3: INTEGER and BIGINT against FLOAT 16777216';
select 'c3a' q, x.id, x.i = y.f, x.b = y.f, x.i > y.f, x.b > y.f from t_flt x, t_flt y where y.id = 3 order by 2;
select 'c3b' q, 16777217 = cast(16777216 as float), cast(16777217 as bigint) = cast(16777216 as float), 16777216 = cast(16777216 as float);


evaluate 'Case 4: index ranges on NUMERIC, INTEGER and BIGINT keys by a FLOAT';
--@queryplan
select /*+ recompile */ 'c4ai' q, id from t_flt force index (i_flt_n) where n = cast(0.3 as float) order by id;
--@queryplan
select /*+ recompile */ 'c4an' q, id from t_flt where n = cast(0.3 as float) using index none order by id;
--@queryplan
select /*+ recompile */ 'c4bi' q, id from t_flt force index (i_flt_i) where i = cast(16777216 as float) order by id;
--@queryplan
select /*+ recompile */ 'c4bn' q, id from t_flt where i = cast(16777216 as float) using index none order by id;
--@queryplan
select /*+ recompile */ 'c4ci' q, id from t_flt force index (i_flt_b) where b = cast(16777216 as float) order by id;
--@queryplan
select /*+ recompile */ 'c4cn' q, id from t_flt where b = cast(16777216 as float) using index none order by id;
--@queryplan
select /*+ recompile */ 'c4di' q, id from t_flt force index (i_flt_n) where n > cast(0.3 as float) order by id;
--@queryplan
select /*+ recompile */ 'c4dn' q, id from t_flt where n > cast(0.3 as float) using index none order by id;


evaluate 'Case 5: result types stay as before';
select 'c5a' q, typeof(n = f), typeof(n + f), typeof(i + f), typeof(b + f) from t_flt where id = 1;

drop table t_flt;
