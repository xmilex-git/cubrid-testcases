--+ server-message on
-- Verified for CBRD-24565

-- normal: basic usage of operator 'between' with double values


create or replace procedure t(i int) as
    a double := 3.5;
    b double := 5.7;
    c double := 7.9;

    function print_bool(b boolean) return varchar as
    begin
        return case when b is null then 'null' when b then 'true' else 'false' end;
    end;
begin
    dbms_output.put_line(print_bool(b between a and c));
    dbms_output.put_line(print_bool(a between b and c));
    dbms_output.put_line(print_bool(null between b and c));
    dbms_output.put_line(print_bool(a between null and c));
    dbms_output.put_line(print_bool(a between b and null));
end;

select count(*) from db_stored_procedure where sp_name = 't';
select count(*) from db_stored_procedure_args where sp_name = 't';

call t(7);

drop procedure t;


--+ server-message off
