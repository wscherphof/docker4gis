create or replace function web.fn_logout()
returns void
language sql
as $$
    update web.tbl_user
    set exp = now()
    ;
$$;

grant execute on function web.fn_logout() to web_user
;
