/*
Test Case: REVOKE authorization
Priority: 1
Reference case:
Author: Bobo

Test Plan: 
Test update locks (X_LOCK on instance) and SELECT not need locks, they are not blocked each other.

Test Scenario:
C1 granting authorization, C2 verify authorization, 
C1 verify authorization, 
C1 commit, C2 commit, 
Metrics: data size = small, where clause = simple (multiple columns)

Test Point:
1) C1 and C2 will not be waiting 
2) All the data affected from C1 and C2 should be deleted

NUM_CLIENTS = 2
C1: granting authorization - verify authorization;  
C2: verify authorization;  
*/

MC: setup NUM_CLIENTS = 2;

C1: login as 'dba';
C1: set transaction lock timeout INFINITE;
C1: set transaction isolation level read committed;

C2: set transaction lock timeout INFINITE;
C2: set transaction isolation level read committed;

/* preparation */
C1: DROP TABLE IF EXISTS t1;
C1: CREATE USER company;
C1: CREATE USER engineering GROUPS company;
C1: CREATE USER jones GROUPS engineering; 
C1: CREATE USER brown;
C1: CREATE USER design MEMBERS brown;
C1: COMMIT;
MC: wait until C1 ready;

C1: CREATE TABLE t1 (id INT primary key);
C1: GRANT SELECT, UPDATE ON t1 TO company;
C1: GRANT SELECT, ALTER, INDEX, DELETE ON t1 TO design;
C1: insert into t1 values (1),(2),(3),(4),(5),(6),(7);
C1: COMMIT;
MC: wait until C1 ready;

C1: REVOKE ALTER ON t1 FROM design;
MC: wait until C1 ready;
C2: login as 'design';
C2: set transaction lock timeout INFINITE;
C2: set transaction isolation level read committed;
C2: TRUNCATE table dba.t1;
MC: wait until C2 blocked;
C1: COMMIT;
MC: wait until C2 ready;
C2: ALTER table dba.t1 ADD COLUMN name VARCHAR;
C2: show COLUMNS in dba.t1;
C2: COMMIT;
MC: wait until C2 ready;
C2: select * from dba.t1 order by 1;
C2: COMMIT;
MC: wait until C2 ready;

C1: login as 'dba';
C1: DROP table t1;
C1: DROP USER jones;
C1: DROP USER brown;
C1: DROP USER design;
C1: DROP USER engineering;
C1: DROP USER company;
C1: COMMIT;
MC: wait until C1 ready;

C1: quit;
C2: quit;

