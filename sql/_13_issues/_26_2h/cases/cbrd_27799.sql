/**
 *  This test case verifies CBRD-27799: an index scan on a multi-column index whose
 *  BIGINT column is searched by a DOUBLE value returns the rows a sequential scan
 *  returns when a later column has a range or equality condition.
 *
 *  Before the fix the sequential scan compared in DOUBLE and took the rows of both
 *  b = 2^53 and b = 2^53+1, while the index scan returned other rows, one of them
 *  failing the condition on c.
 *  With CBRD-27819 the DOUBLE 9007199254740993.0e0 is 2^53 and equals only b = 2^53,
 *  so both scans return the rows of b = 2^53.
 *
 *  Each query runs on the index (USING INDEX, plan printed) and on the heap
 *  (USING INDEX NONE). The two result blocks must be equal and equal to the
 *  expected rows. Case 3 repeats the shape with a DOUBLE host variable.
 *
 *  Coverage:
 *    Case 1:  the issue repro with c >= 5
 *    Case 2:  the issue repro with c = 5
 *    Case 3:  DOUBLE host variable for b
 */

drop table if exists t_gbc;

-- Rows of b = 2^53 and b = 2^53+1 with overlapping c values, so a lost or extra b value changes the rows.
create table t_gbc (g int, b bigint, c int);
insert into t_gbc values (3, 9007199254740992, 5), (3, 9007199254740992, 6), (3, 9007199254740992, 7), (3, 9007199254740993, 1), (3, 9007199254740993, 5);
create index i_gbc on t_gbc (g, b, c);
update statistics on t_gbc with fullscan;


evaluate 'Case 1: the issue repro with c >= 5';
--@queryplan
select /*+ recompile */ 'c1n' q, b, c from t_gbc where g = 3 and b = 9007199254740993.0e0 and c >= 5 using index none order by 2, 3;
--@queryplan
select /*+ recompile */ 'c1i' q, b, c from t_gbc where g = 3 and b = 9007199254740993.0e0 and c >= 5 using index i_gbc order by 2, 3;


evaluate 'Case 2: the issue repro with c = 5';
--@queryplan
select /*+ recompile */ 'c2n' q, b, c from t_gbc where g = 3 and b = 9007199254740993.0e0 and c = 5 using index none order by 2, 3;
--@queryplan
select /*+ recompile */ 'c2i' q, b, c from t_gbc where g = 3 and b = 9007199254740993.0e0 and c = 5 using index i_gbc order by 2, 3;


evaluate 'Case 3: DOUBLE host variable for b';
prepare st_none from 'select /*+ recompile */ ''c3n'' q, ? o, b, c from t_gbc where g = 3 and b = ? and c >= ? using index none order by 3, 4';
prepare st_idx from 'select /*+ recompile */ ''c3i'' q, ? o, b, c from t_gbc where g = 3 and b = ? and c >= ? using index i_gbc order by 3, 4';
execute st_none using 'double', 9007199254740992.0e0, 5;
execute st_idx using 'double', 9007199254740992.0e0, 5;
execute st_none using 'bigint', 9007199254740993, 1;
execute st_idx using 'bigint', 9007199254740993, 1;
deallocate prepare st_none;
deallocate prepare st_idx;

drop table t_gbc;
