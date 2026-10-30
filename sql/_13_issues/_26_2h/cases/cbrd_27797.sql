/**
 *  This test case verifies CBRD-27797: an index scan over k = ? or k = ? with a BIGINT
 *  and a DOUBLE host variable on a BIGINT index returns the rows a sequential scan returns.
 *
 *  Before the fix the key list cleanup judged the BIGINT 2^53+1 and the DOUBLE 2^53 equal
 *  in DOUBLE and dropped one key, so the index scan lost the row k = 2^53 while the
 *  sequential scan returned both rows.
 *  With CBRD-27819 the DOUBLE 2^53 equals only the key 2^53, so the two keys differ.
 *
 *  Each EXECUTE runs on the index (FORCE INDEX, plan printed) and on the heap
 *  (USING INDEX NONE). Both must return v = 1, 2 in both bind orders.
 *
 *  Coverage:
 *    Case 1:  the issue repro, both bind orders, index and sequential scan
 *    Case 2:  the same keys as constants
 *    Case 3:  overlapping ranges from a BIGINT and a DOUBLE bound
 */

drop table if exists t_key;

-- Two BIGINT keys that are equal as DOUBLE.
create table t_key (k bigint, v int);
insert into t_key values (9007199254740992, 1), (9007199254740993, 2);
create index i_key_k on t_key (k);
update statistics on t_key with fullscan;


evaluate 'Case 1: the issue repro, both bind orders, index and sequential scan';
prepare st_idx from 'select /*+ recompile */ ''c1i'' q, ? o, v from t_key force index (i_key_k) where k = ? or k = ? order by v';
prepare st_none from 'select /*+ recompile */ ''c1n'' q, ? o, v from t_key where k = ? or k = ? using index none order by v';
execute st_idx using 'bigint_first', 9007199254740993, 9007199254740992.0e0;
execute st_none using 'bigint_first', 9007199254740993, 9007199254740992.0e0;
execute st_idx using 'double_first', 9007199254740992.0e0, 9007199254740993;
execute st_none using 'double_first', 9007199254740992.0e0, 9007199254740993;
deallocate prepare st_idx;
deallocate prepare st_none;


evaluate 'Case 2: the same keys as constants';
--@queryplan
select /*+ recompile */ 'c2i' q, v from t_key force index (i_key_k) where k = 9007199254740993 or k = 9007199254740992.0e0 order by v;
--@queryplan
select /*+ recompile */ 'c2n' q, v from t_key where k = 9007199254740993 or k = 9007199254740992.0e0 using index none order by v;
--@queryplan
select /*+ recompile */ 'c2ii' q, v from t_key force index (i_key_k) where k in (9007199254740993, 9007199254740992.0e0) order by v;
--@queryplan
select /*+ recompile */ 'c2in' q, v from t_key where k in (9007199254740993, 9007199254740992.0e0) using index none order by v;


evaluate 'Case 3: overlapping ranges from a BIGINT and a DOUBLE bound';
prepare st_rng_idx from 'select /*+ recompile */ ''c3i'' q, v from t_key force index (i_key_k) where k between ? and ? or k between ? and ? order by v';
prepare st_rng_none from 'select /*+ recompile */ ''c3n'' q, v from t_key where k between ? and ? or k between ? and ? using index none order by v';
execute st_rng_idx using 9007199254740993, 9007199254740993, 9007199254740992.0e0, 9007199254740992.0e0;
execute st_rng_none using 9007199254740993, 9007199254740993, 9007199254740992.0e0, 9007199254740992.0e0;
deallocate prepare st_rng_idx;
deallocate prepare st_rng_none;

drop table t_key;
