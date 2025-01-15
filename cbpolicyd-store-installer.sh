#!/bin/bash

# Copyright (C) 2025 BTACTIC, S.C.C.L.
# Copyright (C) 2016-2023  Barry de Graaff
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/.

set -e
# if you want to trace your script uncomment the following line
# set -x
# Pre 2025 - Documentation
# Documentation used from https://www.zimbrafr.org/forum/topic/7623-poc-zimbra-policyd/
# https://wiki.zimbra.com/wiki/Postfix_Policyd#Example_Configuration
# Thanks
# Post 2025 - Documentation
# Original file from: https://github.com/Zimbra-Community/zimbra-tools/blob/master/cbpolicyd.sh

# Auxiliar functions

function usage () {
cat << EOF
Automated cbpolicyd installer for Zimbra mailbox node.

- Installs policyd on MariaDB or MySQL (shipped with Zimbra).
- No webui is installed.
- Aimed at Zimbra 10.0.x
EOF
}

function create_cbpolicyd_mysql_user () {
  cat <<EOF > "${CBPOLICYD_DBCREATE_TMP_SQL}"
CREATE DATABASE ${CBPOLICYD_DATABASE} CHARACTER SET 'UTF8'; 
CREATE USER '${CBPOLICYD_DATABASE_USER}'@'localhost' IDENTIFIED BY '${CBPOLICYD_PWD}'; 
GRANT ALL PRIVILEGES ON ${CBPOLICYD_DATABASE} . * TO '${CBPOLICYD_DATABASE_USER}'@'localhost' WITH GRANT OPTION; 
FLUSH PRIVILEGES ; 
EOF

  "${ZIMBRA_MYSQL_BINARY}" --force < "${CBPOLICYD_DBCREATE_TMP_SQL}" > /dev/null 2>&1
}

function create_cbpolicyd_db_and_user () {
  cat <<EOF > "${CBPOLICYD_DBCREATE_TMP_SQL}"
DROP USER '${CBPOLICYD_DATABASE_USER}'@'localhost';
DROP DATABASE ${CBPOLICYD_DATABASE};
CREATE DATABASE ${CBPOLICYD_DATABASE} CHARACTER SET 'UTF8'; 
CREATE USER '${CBPOLICYD_DATABASE_USER}'@'localhost' IDENTIFIED BY '${CBPOLICYD_PWD}'; 
GRANT ALL PRIVILEGES ON ${CBPOLICYD_DATABASE} . * TO '${CBPOLICYD_DATABASE_USER}'@'localhost' WITH GRANT OPTION; 
FLUSH PRIVILEGES ; 
EOF

  ${ZIMBRA_MYSQL_BINARY} < "${CBPOLICYD_DBCREATE_TMP_SQL}"
}

function populate_cbpolicyd_databases () {
  cd /opt/zimbra/common/share/database/
  for ntsql in \
    core.tsql \
    access_control.tsql \
    quotas.tsql \
    amavis.tsql \
    checkhelo.tsql \
    checkspf.tsql \
    greylisting.tsql \
    accounting.tsql; \
    do 
      ./convert-tsql mysql $ntsql;
done > "${CBPOLICYD_CONTENTS_TMP_SQL}"

  ${ZIMBRA_MYSQL_BINARY} ${CBPOLICYD_DATABASE} < "${CBPOLICYD_CONTENTS_TMP_SQL}"
}

function add_zimbra_policy () {
  cat <<EOF > "${CBPOLICYD_POLICY_SQL}"
INSERT INTO policies (ID, Name,Priority,Description) VALUES(6, 'Zimbra CBPolicyd Policies', 0, 'Zimbra CBPolicyd Policies');
INSERT INTO policy_members (PolicyID,Source,Destination) VALUES(6, 'any', 'any');
INSERT INTO quotas (PolicyID,Name,Track,Period,Verdict,Data) VALUES (6, 'Sender:user@domain','Sender:user@domain', 60, 'DEFER', 'You are sending too many emails, contact helpdesk');
INSERT INTO quotas (PolicyID,Name,Track,Period,Verdict) VALUES (6, 'Recipient:user@domain', 'Recipient:user@domain', 60, 'REJECT');
INSERT INTO quotas_limits (QuotasID,Type,CounterLimit) VALUES(3, 'MessageCount', 100);
INSERT INTO quotas_limits (QuotasID,Type,CounterLimit) VALUES(4, 'MessageCount', 125);
EOF

${ZIMBRA_MYSQL_BINARY} ${CBPOLICYD_DATABASE} < "${CBPOLICYD_POLICY_SQL}"
}

function reporting_commands_install () {
  echo "${ZIMBRA_MYSQL_BINARY} ${CBPOLICYD_DATABASE} -e \"select count(instance) count, sender from session_tracking where date(from_unixtime(unixtimestamp))=curdate() group by sender order by count desc;\"" > /usr/local/sbin/cbpolicyd-report
  chmod +rx /usr/local/sbin/cbpolicyd-report
}

# Definitions

CBPOLICYD_CLEANUP_CRON_FILE='/etc/cron.d/zimbra-cbpolicyd-cleanup'
ZIMBRA_MYSQL_BINARY="/opt/zimbra/bin/mysql"

CBPOLICYD_PWD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 10)
CBPOLICYD_DATABASE_USER='ad-policyd_db'
CBPOLICYD_DATABASE='policyd_db'

CBPOLICYD_DBCREATE_TMP_SQL="$(mktemp /tmp/policyd-dbcreate.XXXXXXXX.sql)"
CBPOLICYD_CONTENTS_TMP_SQL="$(mktemp /tmp/policyd-dbtables.XXXXXXXX.sql)"
CBPOLICYD_POLICY_SQL="$(mktemp /tmp/policyd-policy.XXXXXXXX.sql)"

# Main program

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

create_cbpolicyd_mysql_user # creating a user, just to make sure we have one (for mysql on CentOS 6, so we can execute the next mysql queries w/o errors)
create_cbpolicyd_db_and_user # "Creating database and user"
populate_cbpolicyd_databases # Populating databases
# add_zimbra_policy # Setting basic quota policy
# reporting_commands_install # Installing reporting commands
