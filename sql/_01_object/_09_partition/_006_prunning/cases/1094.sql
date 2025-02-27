-- insert data  whith create hash partition class on a char field with size 8 and query data with function of lower,upper,lpad and rpad and then drop class

create class hash_char (id int, test_char char(2))
partition by hash(test_char) partitions 8;

insert into hash_char values (1,'11');
insert into hash_char values (2,'22');
insert into hash_char values (3,'33');
insert into hash_char values (4,'AA');
insert into hash_char values (5,'bb');
select * from hash_char where test_char = lower('BB');
select * from hash_char where test_char = upper('aa');
select * from hash_char where test_char = lpad('bbbb', 2, '');
select * from hash_char where test_char = rpad('AAAA', 2, '');
drop class hash_char;
