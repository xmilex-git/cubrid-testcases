/**
 *  This test case verifies CBRD-27799: an index scan on a multi-column index whose
 *  BIGINT column is searched by a DOUBLE value returns the rows a sequential scan
 *  returns when a later column has a range or equality condition.
 *
 *  A BIGINT compared with a DOUBLE is compared in DOUBLE. The DOUBLE literal
 *  9007199254740993.0e0 is 2^53, so b = 9007199254740993.0e0 is true for both
 *  b = 2^53 and b = 2^53+1.
 *  Before the fix the sequential scan returned the rows of both b values, while the
 *  index scan searched one key and applied the condition on c to other rows, so it
 *  returned a row that fails c >= 5 and missed rows that pass it.
 *
 *  Each query runs on the index (USING INDEX, plan printed) and on the heap
 *  (USING INDEX NONE). Label q ends in i for the index and n for the heap.
 *  The expected rows of both are the rows of the heap scan.
 *  Case 3 repeats the shape with host variables. ORDER BY uses b + 0 because the
 *  equality on b removes b itself from the sort keys.
 *
 *  Coverage:
 *    Case 1:  the issue repro with c >= 5
 *    Case 2:  the issue repro with c = 5
 *    Case 3:  DOUBLE and BIGINT host variables for b
 */

drop table if exists t_gbc;

-- Rows of b = 2^53 and b = 2^53+1 with overlapping c values, so a lost or extra b value changes the rows.
create table t_gbc (g int, b bigint, c int);
insert into t_gbc values (3, 9007199254740992, 5), (3, 9007199254740992, 6), (3, 9007199254740992, 7), (3, 9007199254740993, 1), (3, 9007199254740993, 5);
create index i_gbc on t_gbc (g, b, c);
update statistics on t_gbc with fullscan;


evaluate 'Case 1: the issue repro with c >= 5';
--@queryplan
select /*+ recompile */ 'c1an' q, b, c from t_gbc where g = 3 and b = 9007199254740993.0e0 and c >= 5 using index none order by b + 0, c;
--@queryplan
select /*+ recompile */ 'c1ai' q, b, c from t_gbc where g = 3 and b = 9007199254740993.0e0 and c >= 5 using index i_gbc order by b + 0, c;


evaluate 'Case 2: the issue repro with c = 5';
--@queryplan
select /*+ recompile */ 'c2an' q, b, c from t_gbc where g = 3 and b = 9007199254740993.0e0 and c = 5 using index none order by b + 0, c;
--@queryplan
select /*+ recompile */ 'c2ai' q, b, c from t_gbc where g = 3 and b = 9007199254740993.0e0 and c = 5 using index i_gbc order by b + 0, c;


evaluate 'Case 3: DOUBLE and BIGINT host variables for b';
prepare st_none from 'select /*+ recompile */ ? q, b, c from t_gbc where g = 3 and b = ? and c >= ? using index none order by b + 0, c';
prepare st_idx from 'select /*+ recompile */ ? q, b, c from t_gbc where g = 3 and b = ? and c >= ? using index i_gbc order by b + 0, c';
execute st_none using 'c3an', 9007199254740992.0e0, 5;
execute st_idx using 'c3ai', 9007199254740992.0e0, 5;
execute st_none using 'c3bn', 9007199254740993, 1;
execute st_idx using 'c3bi', 9007199254740993, 1;
deallocate prepare st_none;
deallocate prepare st_idx;

drop table t_gbc;
