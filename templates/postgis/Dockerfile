FROM docker4gis/postgis:659-16-3.4

ENV POSTFIX_DOMAIN=template.example.com

# To create a mail box {login}@${POSTFIX_DOMAIN}:
# RUN addmailbox.sh {login} 'Full Name'
RUN addmailbox.sh noreply 'Example.com Template Service'

# The following schemas are skipped on `dump` or `upgrade`;
# use `dump_schema` and `restore_schema` for those.
# E.g. (see https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-PATTERNS):
# ENV EXCLUDE_SCHEMA=(interpolatie|utils)
ENV EXCLUDE_SCHEMA=

# Optionally include dump files in this directory to kickstart an empty database
# instead of fully building it from the ddl scripts.
COPY conf/snapshot /snapshot

# On container start, /ddl/conf.sh is executed.
COPY conf/ddl /ddl
