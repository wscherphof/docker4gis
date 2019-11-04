create table if not exists web.tbl_user
    ( email text primary key check ( email ~* '^.+@.+\..+$' )
    , role  name not null unique check ( length(role) < 512 )
    , pass  text default null check ( length(pass) < 512 )
    , exp   timestamp with time zone default null
);

-- We would like the role to be a foreign key to actual database roles, however
-- PostgreSQL does not support these constraints against the pg_roles table.
-- We’ll use a trigger to manually enforce it.

create or replace function web.tr_check_role_exists
    ( )
returns trigger
language plpgsql
as $$
begin
    if not exists (select from pg_roles as r where r.rolname = new.role) then
        raise foreign_key_violation using message =
            'unknown database role: ' || new.role
        ;
    end if;
    return new;
end;
$$;

create constraint trigger tr_check_user_role_exists
after insert or update on web.tbl_user
for each row
execute function web.tr_check_role_exists()
;

alter table web.tbl_user
enable row level security
;

grant select on web.tbl_user to web_anon
;
create policy pol_user_web_anon on web.tbl_user to web_anon
using (false)
;

grant select on web.tbl_user to web_passwd
;
create policy pol_user_web_passwd on web.tbl_user to web_passwd
using (false)
;

grant select, update on web.tbl_user to web_user
;
create policy pol_user_web_user on web.tbl_user to web_user
using (role = current_user)
with check (role = current_user)
;
