/**
 *  This test case verifies CBRD-27797: an index scan over k = ? or k = ? with a BIGINT
 *  and a DOUBLE host variable on a BIGINT index returns the rows a sequential scan returns.
 *
 *  A BIGINT compared with a DOUBLE is compared in DOUBLE, so the DOUBLE 2^53 equals both
 *  keys 2^53 and 2^53+1, and the BIGINT 2^53+1 equals only the key 2^53+1.
 *  Before the fix the key list cleanup judged the two search keys equal in DOUBLE and
 *  dropped one of them, so the index scan lost the row k = 2^53 when the BIGINT came
 *  first. The same cleanup on an IN list or an OR of constants lost the row on the
 *  index scan and, for the OR of constants, on the sequential scan too.
 *
 *  Each query runs on the index (FORCE INDEX, plan printed) and on the heap
 *  (USING INDEX NONE). Label q ends in i for the index and n for the heap.
 *  The expected rows are the rows of a heap scan that compares every row
 *  in DOUBLE: v = 1, 2 for every query of this file.
 *
 *  Coverage:
 *    Case 1:  the issue repro, both bind orders
 *    Case 2:  the same keys as constants, OR and IN list
 *    Case 3:  overlapping ranges from a BIGINT and a DOUBLE bound
 */

drop table if exists t_key;

-- Two BIGINT keys that are equal as DOUBLE.
create table t_key (k bigint, v int);
insert into t_key values (9007199254740992, 1), (9007199254740993, 2);
create index i_key_k on t_key (k);
update statistics on t_key with fullscan;


evaluate 'Case 1: the issue repro, both bind orders';
prepare st_idx from 'select /*+ recompile */ ? q, v from t_key force index (i_key_k) where k = ? or k = ? order by v';
prepare st_none from 'select /*+ recompile */ ? q, v from t_key where k = ? or k = ? using index none order by v';
execute st_idx using 'c1ai', 9007199254740993, 9007199254740992.0e0;
execute st_none using 'c1an', 9007199254740993, 9007199254740992.0e0;
execute st_idx using 'c1bi', 9007199254740992.0e0, 9007199254740993;
execute st_none using 'c1bn', 9007199254740992.0e0, 9007199254740993;
deallocate prepare st_idx;
deallocate prepare st_none;


evaluate 'Case 2: the same keys as constants, OR and IN list';
--@queryplan
select /*+ recompile */ 'c2ai' q, v from t_key force index (i_key_k) where k = 9007199254740993 or k = 9007199254740992.0e0 order by v;
--@queryplan
select /*+ recompile */ 'c2an' q, v from t_key where k = 9007199254740993 or k = 9007199254740992.0e0 using index none order by v;
--@queryplan
select /*+ recompile */ 'c2bi' q, v from t_key force index (i_key_k) where k in (9007199254740993, 9007199254740992.0e0) order by v;
--@queryplan
select /*+ recompile */ 'c2bn' q, v from t_key where k in (9007199254740993, 9007199254740992.0e0) using index none order by v;


evaluate 'Case 3: overlapping ranges from a BIGINT and a DOUBLE bound';
prepare st_rng_idx from 'select /*+ recompile */ ? q, v from t_key force index (i_key_k) where k between ? and ? or k between ? and ? order by v';
prepare st_rng_none from 'select /*+ recompile */ ? q, v from t_key where k between ? and ? or k between ? and ? using index none order by v';
execute st_rng_idx using 'c3ai', 9007199254740993, 9007199254740993, 9007199254740992.0e0, 9007199254740992.0e0;
execute st_rng_none using 'c3an', 9007199254740993, 9007199254740993, 9007199254740992.0e0, 9007199254740992.0e0;
deallocate prepare st_rng_idx;
deallocate prepare st_rng_none;

drop table t_key;
