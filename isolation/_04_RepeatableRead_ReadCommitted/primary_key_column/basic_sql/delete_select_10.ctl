/*
Test Case: delete & select
Priority: 2
Reference case: cc_basic/_01_ReadCommitted/primary_key_column/basic_sql
Author: Lily

Test Point:
changes can be seen after committed.

NUM_CLIENTS = 2
C1: DELETE FROM tb1 WHERE id <= 2;
C2: SELECT * FROM tb1 ORDER BY id;
*/

MC: setup NUM_CLIENTS = 2;
C1: set transaction lock timeout INFINITE;
C1: set transaction isolation level repeatable read;

C2: set transaction lock timeout INFINITE;
C2: set transaction isolation level read committed;

/* preparation */
C1: DROP TABLE IF EXISTS tb1;
C1: CREATE TABLE tb1(id INT PRIMARY KEY,col VARCHAR(10));
C1: INSERT INTO tb1 VALUES(1,'abc');INSERT INTO tb1 VALUES(2,'EFD');INSERT INTO tb1 VALUES(3,'IHT');INSERT INTO tb1 VALUES(4,'xyz');INSERT INTO tb1 VALUES(5,'mnf');INSERT INTO tb1 VALUES(6,'lop');INSERT INTO tb1 VALUES(7,'tea');
C1: commit;

MC: wait until C1 ready;
/* test case */
C1: DELETE FROM tb1 WHERE id <= 3;
MC: wait until C1 ready;
C2: SELECT * FROM tb1 ORDER BY id;
MC: wait until C2 ready;
C1: commit;
MC: wait until C1 ready;
C2: SELECT * FROM tb1 ORDER BY id;
C2: commit;

C2: quit;
C1: quit;
