/**
 *  This test case verifies CBRD-27819: an index scan whose key range comes from a DOUBLE
 *  value on a BIGINT or NUMERIC key returns the rows a sequential scan returns.
 *
 *  Before the fix both scans compared in DOUBLE, so b = 2^53 as DOUBLE took the keys 2^53
 *  and 2^53+1, b > 2^53 found nothing, and NUMERIC(10,2) against 1e20 raised a coercion
 *  error. The fix rounds the comparison value up or down to the key domain. A non-integer
 *  equality is an empty range, a value outside the domain gives an empty or a full range.
 *
 *  Each query runs on the index (FORCE INDEX, plan printed, iscan) and again with
 *  USING INDEX NONE (sscan). The two result blocks must be equal and equal to the
 *  expected rows. Correctness TC with a twin per query.
 *
 *  Coverage:
 *    Case 1:  BIGINT equality at 2^53, 2^57 and 2^63
 *    Case 2:  BIGINT ranges with fractional and out-of-domain bounds
 *    Case 3:  NUMERIC(10,2) bounds at 0.30000000000000004 and 1e20
 *    Case 4:  NUMERIC(38) equality at 2^57 and with 17 digits
 *    Case 5:  primary key lookup by a DOUBLE
 *    Case 6:  DOUBLE host variables as key range bounds
 */

drop table if exists t_big, t_num, t_wide, t_pk;

-- BIGINT keys around 2^53, 2^57 and both ends of BIGINT, and small integers for fractional bounds.
create table t_big (id int, b bigint);
insert into t_big values (1, 0), (2, 1), (3, 2), (4, 3), (5, 9007199254740992), (6, 9007199254740993), (7, 9223372036854775807), (8, -9223372036854775808), (9, 144115188075855870), (10, 144115188075855872), (11, 144115188075855873);
create index i_big_b on t_big (b);
-- NUMERIC(10,2) keys near 0.3 and at the top of the domain.
create table t_num (id int, n numeric(10,2));
insert into t_num values (1, 0.10), (2, 0.20), (3, 0.30), (4, 0.31), (5, 99999999.99);
create index i_num_n on t_num (n);
-- NUMERIC(38) keys that are equal as DOUBLE at 2^57 plus one 17-digit key.
create table t_wide (id int, n numeric(38,0));
insert into t_wide values (1, 144115188075855870), (2, 144115188075855872), (3, 144115188075855873), (4, 12345678901234568);
create index i_wide_n on t_wide (n);
-- Primary key values 2^53 and 2^53+1.
create table t_pk (k bigint primary key, v int);
insert into t_pk values (9007199254740992, 1), (9007199254740993, 2);
update statistics on t_big, t_num, t_wide, t_pk with fullscan;


evaluate 'Case 1: BIGINT equality at 2^53, 2^57 and 2^63';
--@queryplan
select /*+ recompile */ 'c1ai' q, b from t_big force index (i_big_b) where b = 9007199254740992e0 order by b;
--@queryplan
select /*+ recompile */ 'c1an' q, b from t_big where b = 9007199254740992e0 using index none order by b;
--@queryplan
select /*+ recompile */ 'c1bi' q, b from t_big force index (i_big_b) where b = 144115188075855872e0 order by b;
--@queryplan
select /*+ recompile */ 'c1bn' q, b from t_big where b = 144115188075855872e0 using index none order by b;
--@queryplan
select /*+ recompile */ 'c1ci' q, count(*) from t_big force index (i_big_b) where b = 9223372036854775807e0;
--@queryplan
select /*+ recompile */ 'c1cn' q, count(*) from t_big where b = 9223372036854775807e0 using index none;


evaluate 'Case 2: BIGINT ranges with fractional and out-of-domain bounds';
--@queryplan
select /*+ recompile */ 'c2ai' q, b from t_big force index (i_big_b) where b > 9007199254740992e0 and b < 9007199254741000 order by b;
--@queryplan
select /*+ recompile */ 'c2an' q, b from t_big where b > 9007199254740992e0 and b < 9007199254741000 using index none order by b;
--@queryplan
select /*+ recompile */ 'c2bi' q, count(*), min(b) from t_big force index (i_big_b) where b > 0.5e0;
--@queryplan
select /*+ recompile */ 'c2bn' q, count(*), min(b) from t_big where b > 0.5e0 using index none;
--@queryplan
select /*+ recompile */ 'c2ci' q, b from t_big force index (i_big_b) where b between 0.5e0 and 2.5e0 order by b;
--@queryplan
select /*+ recompile */ 'c2cn' q, b from t_big where b between 0.5e0 and 2.5e0 using index none order by b;
--@queryplan
select /*+ recompile */ 'c2di' q, count(*) from t_big force index (i_big_b) where b <= 1e20;
--@queryplan
select /*+ recompile */ 'c2dn' q, count(*) from t_big where b <= 1e20 using index none;
--@queryplan
select /*+ recompile */ 'c2ei' q, count(*) from t_big force index (i_big_b) where b = 0.5e0;
--@queryplan
select /*+ recompile */ 'c2en' q, count(*) from t_big where b = 0.5e0 using index none;
--@queryplan
select /*+ recompile */ 'c2fi' q, count(*) from t_big force index (i_big_b) where b >= 9223372036854775807e0;
--@queryplan
select /*+ recompile */ 'c2fn' q, count(*) from t_big where b >= 9223372036854775807e0 using index none;
--@queryplan
select /*+ recompile */ 'c2gi' q, count(*) from t_big force index (i_big_b) where b <= -9223372036854775808e0;
--@queryplan
select /*+ recompile */ 'c2gn' q, count(*) from t_big where b <= -9223372036854775808e0 using index none;
--@queryplan
select /*+ recompile */ 'c2hi' q, count(*) from t_big force index (i_big_b) where b < 9223372036854775807e0;
--@queryplan
select /*+ recompile */ 'c2hn' q, count(*) from t_big where b < 9223372036854775807e0 using index none;


evaluate 'Case 3: NUMERIC(10,2) bounds at 0.30000000000000004 and 1e20';
--@queryplan
select /*+ recompile */ 'c3ai' q, count(*) from t_num force index (i_num_n) where n = 1e20;
--@queryplan
select /*+ recompile */ 'c3an' q, count(*) from t_num where n = 1e20 using index none;
--@queryplan
select /*+ recompile */ 'c3bi' q, count(*) from t_num force index (i_num_n) where n <= 1e20;
--@queryplan
select /*+ recompile */ 'c3bn' q, count(*) from t_num where n <= 1e20 using index none;
--@queryplan
select /*+ recompile */ 'c3ci' q, count(*), max(n) from t_num force index (i_num_n) where n < 0.30000000000000004e0;
--@queryplan
select /*+ recompile */ 'c3cn' q, count(*), max(n) from t_num where n < 0.30000000000000004e0 using index none;
--@queryplan
select /*+ recompile */ 'c3di' q, count(*) from t_num force index (i_num_n) where n = 0.1e0 + 0.2e0;
--@queryplan
select /*+ recompile */ 'c3dn' q, count(*) from t_num where n = 0.1e0 + 0.2e0 using index none;
--@queryplan
select /*+ recompile */ 'c3ei' q, n from t_num force index (i_num_n) where n = 0.3e0 order by n;
--@queryplan
select /*+ recompile */ 'c3en' q, n from t_num where n = 0.3e0 using index none order by n;
--@queryplan
select /*+ recompile */ 'c3fi' q, count(*) from t_num force index (i_num_n) where n > -1e20;
--@queryplan
select /*+ recompile */ 'c3fn' q, count(*) from t_num where n > -1e20 using index none;


evaluate 'Case 4: NUMERIC(38) equality at 2^57 and with 17 digits';
--@queryplan
select /*+ recompile */ 'c4ai' q, id from t_wide force index (i_wide_n) where n = 144115188075855872e0 order by id;
--@queryplan
select /*+ recompile */ 'c4an' q, id from t_wide where n = 144115188075855872e0 using index none order by id;
--@queryplan
select /*+ recompile */ 'c4bi' q, id from t_wide force index (i_wide_n) where n = 12345678901234568e0 order by id;
--@queryplan
select /*+ recompile */ 'c4bn' q, id from t_wide where n = 12345678901234568e0 using index none order by id;


evaluate 'Case 5: primary key lookup by a DOUBLE';
--@queryplan
select /*+ recompile */ 'c5ai' q, v from t_pk where k = 9007199254740993e0 order by v;
--@queryplan
select /*+ recompile */ 'c5an' q, v from t_pk where k = 9007199254740993e0 using index none order by v;
--@queryplan
select /*+ recompile */ 'c5bi' q, v from t_pk where k = 9007199254740992e0 order by v;
--@queryplan
select /*+ recompile */ 'c5bn' q, v from t_pk where k = 9007199254740992e0 using index none order by v;


evaluate 'Case 6: DOUBLE host variables as key range bounds';
prepare st_idx from 'select /*+ recompile */ ''c6ai'' q, b from t_big force index (i_big_b) where b = ? order by b';
prepare st_none from 'select /*+ recompile */ ''c6an'' q, b from t_big where b = ? using index none order by b';
execute st_idx using 9007199254740992e0;
execute st_none using 9007199254740992e0;
prepare st_rng_idx from 'select /*+ recompile */ ''c6bi'' q, b from t_big force index (i_big_b) where b > ? and b < ? order by b';
prepare st_rng_none from 'select /*+ recompile */ ''c6bn'' q, b from t_big where b > ? and b < ? using index none order by b';
execute st_rng_idx using 9007199254740992e0, 9007199254741000;
execute st_rng_none using 9007199254740992e0, 9007199254741000;
deallocate prepare st_idx;
deallocate prepare st_none;
deallocate prepare st_rng_idx;
deallocate prepare st_rng_none;

drop table t_big, t_num, t_wide, t_pk;
