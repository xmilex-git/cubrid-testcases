--create range partition table with nchar data type,insert data to this table and select data in where clause with keyword 'in', 'not in', 'not null', 'not between','<>'

create table range_test(id int not null  ,
				test_char char(50),
				test_varchar varchar(2000),
				test_bit bit(16),
				test_varbit bit varying(20),
				test_nchar nchar(50),
				test_nvarchar nchar varying(2000),
				test_string string,
				test_datetime timestamp,primary key (id,test_nchar))
	PARTITION BY RANGE (test_nchar) (
	PARTITION p0 VALUES LESS THAN (N'ddd'),
	PARTITION p1 VALUES LESS THAN (N'ggg'),
	PARTITION p2 VALUES LESS THAN MAXVALUE
	);
	insert into range_test values(1,'aaa','aaa',B'1',B'1011',N'aaa',N'aaa','aaaaaaaaaa','2007-01-01 09:00:00');
	insert into range_test values(2,'bbb','bbb',B'10',B'1100',N'bbb',N'bbb','bbbbbbbbbb','2007-01-01 09:00:00');
	insert into range_test values(3,'ccc','ccc',B'11',B'1101',N'ccc',N'ccc','cccccccccc','2007-01-01 09:00:00');
	insert into range_test values(4,'ddd','ddd',B'100',B'1110',N'ddd',N'ddd','dddddddddd','2007-01-01 09:00:00');
	insert into range_test values(5,'eee','eee',B'101',B'1111',N'eee',N'eee','eeeeeeeeee','2007-01-01 09:00:00');
	insert into range_test values(6,'fff','fff',B'101',B'1111',N'fff',N'eee','eeeeeeeeee','2007-01-01 09:00:00');
	insert into range_test values(7,'hhh','hhh',B'101',B'1111',N'hhh',N'eee','hhhhhhhhhh','2007-01-01 09:00:00');
	insert into range_test values(8,'iii','iii',B'101',B'1111',N'iii',N'eee','iiiiiiiiii','2007-01-01 09:00:00');
	insert into range_test values( 9,null,null,null,null,null,null,null,'2007-01-01 09:00:00');
select * from range_test where test_nchar in (N'aaa',N'ddd',N'iii') order by 1,2;

select * from range_test where test_nchar not in (N'bbb',N'eee',N'hhh') order by 1,2;
select * from range_test where  test_nchar is not null order by 1,2;
select * from range_test where test_nchar not between N'bbb' and N'ggg' order by 1,2;
select * from range_test where test_nchar <> N'ccc' order by 1,2;
select * from range_test where test_nchar <> N'hhh' order by 1,2;
drop class range_test;
