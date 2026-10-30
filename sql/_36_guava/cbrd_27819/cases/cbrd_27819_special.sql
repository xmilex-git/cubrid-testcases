/**
 *  This test case verifies CBRD-27819: infinity, NaN, negative zero and DOUBLE values
 *  outside NUMERIC(38) compare with BIGINT and NUMERIC without an error, in one total
 *  order, on the index and on the heap alike.
 *
 *  The order is -inf, every number, +inf, NaN, and NaN equals only NaN. Negative zero
 *  compares as 0. Before the fix NaN was equal to every BIGINT and NUMERIC value and
 *  an index range n > NaN returned a row that a sequential scan did not.
 *
 *  Correctness TC: expected literal results. Index queries run with FORCE INDEX and
 *  with USING INDEX NONE, plan printed. INTEGER against DOUBLE keeps its DOUBLE
 *  comparison and is printed as a control that does not change.
 *
 *  Coverage:
 *    Case 1:  BIGINT and NUMERIC columns against inf, -inf, NaN and 1e40
 *    Case 2:  constants against NaN, INTEGER control
 *    Case 3:  negative zero
 *    Case 4:  NUMERIC(38) and BIGINT limits against large and tiny DOUBLE values
 *    Case 5:  index ranges bounded by inf, -inf and NaN
 */

drop table if exists t_spc, t_zero, t_ix;

-- One BIGINT and two NUMERIC columns next to each special DOUBLE.
create table t_spc (id int, d double, b bigint, n numeric(38,0), m numeric(10,2));
insert into t_spc values (1, cast('inf' as double), 5, 5, 5.00);
insert into t_spc values (2, cast('-inf' as double), 5, 5, 5.00);
insert into t_spc values (3, cast('nan' as double), 5, 5, 5.00);
insert into t_spc values (4, 1e40, 5, 99999999999999999999999999999999999999, 5.00);
insert into t_spc values (5, -1e40, 5, -99999999999999999999999999999999999999, 5.00);
insert into t_spc values (6, 1e38, 5, 99999999999999999999999999999999999999, 5.00);
-- Negative zero next to zeros of each type.
create table t_zero (d double, b bigint, n numeric(38,0), m numeric(10,2));
insert into t_zero values (-0e0, 0, 0, 0.00);
-- Indexed BIGINT and NUMERIC keys for ranges bounded by special values.
create table t_ix (b bigint, n numeric(10,2));
insert into t_ix values (1, 1.00), (2, 2.00), (-3, -3.00);
create index i_ix_b on t_ix (b);
create index i_ix_n on t_ix (n);
update statistics on t_spc, t_zero, t_ix with fullscan;


evaluate 'Case 1: BIGINT and NUMERIC columns against inf, -inf, NaN and 1e40';
select 'c1a' q, id, b = d, b < d, b > d from t_spc order by id;
select 'c1b' q, id, n = d, n < d, n > d from t_spc order by id;
select 'c1c' q, id, m = d, m < d, m > d from t_spc order by id;


evaluate 'Case 2: constants against NaN, INTEGER control';
select 'c2a' q, cast(5 as bigint) = cast('nan' as double), cast(5 as bigint) < cast('nan' as double), cast(5 as bigint) > cast('nan' as double);
select 'c2b' q, cast(5 as numeric(10,2)) = cast('nan' as double), cast(5 as numeric(10,2)) < cast('nan' as double), cast(5 as numeric(10,2)) > cast('nan' as double);
select 'c2c' q, cast('inf' as double) < cast(9223372036854775807 as bigint), cast('-inf' as double) < cast(-9223372036854775808 as bigint);
select 'c2d' q, 5 = cast('nan' as double), 5 < cast('nan' as double), 5 > cast('nan' as double);


evaluate 'Case 3: negative zero';
select 'c3a' q, 0 = -0e0, cast(0 as numeric(10,2)) = -0e0, cast(0 as bigint) < -0e0, cast(0 as bigint) > -0e0;
select 'c3b' q, b = d, n = d, m = d, b > d, b < d from t_zero;


evaluate 'Case 4: NUMERIC(38) and BIGINT limits against large and tiny DOUBLE values';
select 'c4a' q, cast(99999999999999999999999999999999999999 as numeric(38)) = 1e38, cast(99999999999999999999999999999999999999 as numeric(38)) < 1e38, cast(99999999999999999999999999999999999999 as numeric(38)) < 1e40, cast(-99999999999999999999999999999999999999 as numeric(38)) > -1e40;
select 'c4b' q, cast(99999999.99 as numeric(10,2)) < 1e300, cast(99999999.99 as numeric(10,2)) > -1e300, 9223372036854775807 < 1e300, -9223372036854775807 > -1e300;
select 'c4c' q, cast(0 as numeric(10,2)) < 1e-300, cast(0 as numeric(10,2)) = 1e-300, cast(0 as numeric(38,37)) < 1e-300, cast(0 as bigint) < 1e-300, cast(0 as bigint) > -1e-300;


evaluate 'Case 5: index ranges bounded by inf, -inf and NaN';
--@queryplan
select /*+ recompile */ 'c5ai' q, count(*) from t_ix force index (i_ix_b) where b < cast('inf' as double);
--@queryplan
select /*+ recompile */ 'c5an' q, count(*) from t_ix where b < cast('inf' as double) using index none;
--@queryplan
select /*+ recompile */ 'c5bi' q, count(*) from t_ix force index (i_ix_b) where b > cast('-inf' as double);
--@queryplan
select /*+ recompile */ 'c5bn' q, count(*) from t_ix where b > cast('-inf' as double) using index none;
--@queryplan
select /*+ recompile */ 'c5ci' q, count(*) from t_ix force index (i_ix_b) where b < cast('nan' as double);
--@queryplan
select /*+ recompile */ 'c5cn' q, count(*) from t_ix where b < cast('nan' as double) using index none;
--@queryplan
select /*+ recompile */ 'c5di' q, count(*) from t_ix force index (i_ix_b) where b > cast('nan' as double);
--@queryplan
select /*+ recompile */ 'c5dn' q, count(*) from t_ix where b > cast('nan' as double) using index none;
--@queryplan
select /*+ recompile */ 'c5ei' q, count(*) from t_ix force index (i_ix_b) where b = cast('nan' as double);
--@queryplan
select /*+ recompile */ 'c5en' q, count(*) from t_ix where b = cast('nan' as double) using index none;
--@queryplan
select /*+ recompile */ 'c5fi' q, count(*) from t_ix force index (i_ix_n) where n < cast('inf' as double);
--@queryplan
select /*+ recompile */ 'c5fn' q, count(*) from t_ix where n < cast('inf' as double) using index none;
--@queryplan
select /*+ recompile */ 'c5gi' q, count(*) from t_ix force index (i_ix_n) where n < cast('nan' as double);
--@queryplan
select /*+ recompile */ 'c5gn' q, count(*) from t_ix where n < cast('nan' as double) using index none;
--@queryplan
select /*+ recompile */ 'c5hi' q, count(*) from t_ix force index (i_ix_n) where n > cast('nan' as double);
--@queryplan
select /*+ recompile */ 'c5hn' q, count(*) from t_ix where n > cast('nan' as double) using index none;
--@queryplan
select /*+ recompile */ 'c5ii' q, count(*) from t_ix force index (i_ix_n) where n >= cast('-inf' as double);
--@queryplan
select /*+ recompile */ 'c5in' q, count(*) from t_ix where n >= cast('-inf' as double) using index none;

drop table t_spc, t_zero, t_ix;
