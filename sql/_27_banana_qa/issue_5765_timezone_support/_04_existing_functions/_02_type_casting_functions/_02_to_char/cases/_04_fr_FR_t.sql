--test to_char function with TIME(L)TZ columns, with fr_FR language
--+ holdcas on;
set system parameters 'tz_leap_second_support=yes';


set system parameters 'intl_date_lang=fr_FR';
set names utf8;

create table tz_test(id int primary key, ts datetime , dtltz datetime with local time zone, dttz datetime with time zone);

set time zone 'America/Sao_Paulo'; 
insert into tz_test values(1, '2015-9-17 22:30:45', '2015-9-17 22:30:45 -2:25', '2015-9-17 22:30:45 America/Sao_Paulo');
set time zone 'America/Mexico_City';
insert into tz_test values(2, datetime'2015-9-17 7:30:21 PM', datetimetz'2015-9-17 7:30:21 PM +10:30', datetimetz'2015-9-17 7:30:21 PM America/New_York');
set time zone 'Asia/Shanghai';
insert into tz_test values(3, '2015-9-17 7:30:21', '2015-9-17 7:30:21 10:00', '2015-9-17 7:30:21 Asia/Seoul');
set time zone 'Europe/London'; 
insert into tz_test values(4, '2015-9-17 12:59:59  AM', '2015-9-17 23:59:59 UTC', '2015-9-17 12:59:59  AM Europe/London');

set time zone 'America/Sao_Paulo'; 
--test: new tokens
select id, to_char(ts, 'TZR') ts, to_char(dtltz, 'TZR') dttz1, to_char(dttz, 'TZR') dttz2 from tz_test order by id;
select id, to_char(ts, 'TZR TZD') ts, to_char(dtltz, 'TZR TZD') dttz1, to_char(dttz, 'TZR TZD') dttz2 from tz_test order by id;
select id, to_char(ts, 'TZH') ts, to_char(dtltz, 'TZH') dttz1, to_char(dttz, 'TZH') dttz2 from tz_test order by id;
select id, to_char(ts, 'TZH:TZM') ts, to_char(dtltz, 'TZH:TZM') dttz1, to_char(dttz, 'TZH:TZM') dttz2 from tz_test order by id;
--test: [er] unsupported combination
select id, to_char(ts, 'TZH TZR') ts from tz_test order by id;
select id, to_char(dtltz, 'TZD:TZM') from tz_test order by id;
select id, to_char(ts, 'TZH:TZM TZR TZD') from tz_test order by id;

--test: default format
select id, to_char(ts), to_char(dtltz), to_char(dttz) from tz_test order by 1;

--test: ps, with format argument
prepare st from 'select id, to_char(ts, ?), to_char(dtltz, ?), to_char(dttz, ?) from tz_test order by 1';
execute st using 'CC, YY/MM/DD HH:MI:SS.FF A.M.', 'CC, YY/MM/DD HH:MI:SS.FF A.M.', 'CC, YY/MM/DD HH:MI:SS.FF A.M.';
execute st using 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR';
execute st using 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR TZD', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR TZD', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR TZD';
execute st using 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZH:TZM', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZH:TZM', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZH:TZM';

set time zone -6:23;
execute st using 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR';
execute st using 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZD', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZD', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZD';
execute st using 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZH:TZM', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZH:TZM', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZH:TZM';
execute st using 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR TZD', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR TZD', 'CC, YY/MM/DD HH:MI:SS.FF A.M. TZR TZD';

set time zone 'America/Mexico_City';
execute st using 'DD"th", YYYY; DY/d HH24:MI:SS', 'DD"th", YYYY; DY/d HH24:MI:SS', 'DD"th", YYYY; DY/d HH24:MI:SS';
execute st using 'DD"th", YYYY; DY/d HH24:MI:SS TZR', 'DD"th", YYYY; DY/d HH24:MI:SS TZR', 'DD"th", YYYY; DY/d HH24:MI:SS TZR';
execute st using 'DD"th", YYYY; DY/d HH24:MI:SS TZR TZD', 'DD"th", YYYY; DY/d HH24:MI:SS TZR TZD', 'DD"th", YYYY; DY/d HH24:MI:SS TZR TZD';
execute st using 'DD"th", YYYY; DY/d HH24:MI:SS TZH', 'DD"th", YYYY; DY/d HH24:MI:SS TZH', 'DD"th", YYYY; DY/d HH24:MI:SS TZH';
execute st using 'DD"th", YYYY; DY/d HH24:MI:SS TZH TZM', 'DD"th", YYYY; DY/d HH24:MI:SS TZH TZM', 'DD"th", YYYY; DY/d HH24:MI:SS TZH TZM';
deallocate prepare st;

set time zone 'Asia/Shanghai';
--test: with date_lang_string_literal argument
set system parameters 'intl_date_lang=ko_KR';
prepare st from 'select id, to_char(ts, ?, ''fr_FR''), to_char(dtltz, ?, ''fr_FR''), to_char(dttz, ?, ''fr_FR'') from tz_test order by 1';

execute st using 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM';
execute st using 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZR', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZR', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZR';
execute st using 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZR TZD', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZR TZD', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZR TZD';
execute st using 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZH', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZH', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZH';
execute st using 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZH:TZM', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZH:TZM', 'YYYY "Quarter " Q, MONTH-DD DAY HH:MI:SS.FF PM TZH:TZM';
deallocate prepare st;


--test: leap seconds
set time zone 'Europe/London';
prepare st from 'select id, to_char(ts+1, ?, ''fr_FR''), to_char(dtltz+1, ?, ''fr_FR''), to_char(dttz+1, ?, ''fr_FR'') from tz_test order by 1';

execute st using 'MM/DD/YYYY HH24:MI:SS.FF TZR', 'MM/DD/YYYY HH24:MI:SS.FF TZR', 'MM/DD/YYYY HH24:MI:SS.FF TZR';
execute st using 'MM/DD/YYYY HH24:MI:SS.FF TZR;TZD', 'MM/DD/YYYY HH24:MI:SS.FF TZR;TZD', 'MM/DD/YYYY HH24:MI:SS.FF TZR;TZD';
execute st using 'MM/DD/YYYY HH24:MI:SS.FF TZH:TZM', 'MM/DD/YYYY HH24:MI:SS.FF TZH:TZM', 'MM/DD/YYYY HH24:MI:SS.FF TZH:TZM';
execute st using 'MM/DD/YYYY HH24:MI:SS.FF TZD', 'MM/DD/YYYY HH24:MI:SS.FF TZD', 'MM/DD/YYYY HH24:MI:SS.FF TZD';


deallocate prepare st;
drop table tz_test;

set time zone 0:00;
set system parameters 'intl_date_lang=en_US';
set names iso88591;
set system parameters 'tz_leap_second_support=no';

--+ holdcas off;
