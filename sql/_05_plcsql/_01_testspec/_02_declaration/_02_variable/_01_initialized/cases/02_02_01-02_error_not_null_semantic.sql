--+ server-message on

-- error: null value for a not null variable

create or replace procedure t(i int) as
    p_int int not null := null;
begin
    null;
end;

select count(*) from db_stored_procedure where sp_name = 't';
select count(*) from db_stored_procedure_args where sp_name = 't';


--+ server-message off
