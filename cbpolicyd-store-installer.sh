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

Multi server install:
Usage:   $0
Example: $0

Single server install:
Usage:   $0 --single
Example: $0 --single

EOF
}

function create_cbpolicyd_db_and_user () {
  cat <<EOF > "${CBPOLICYD_DBCREATE_TMP_SQL}"
DROP USER IF EXISTS '${CBPOLICYD_DATABASE_USER}'@'localhost';
DROP DATABASE IF EXISTS ${CBPOLICYD_DATABASE};
CREATE DATABASE ${CBPOLICYD_DATABASE} CHARACTER SET 'UTF8'; 
CREATE USER '${CBPOLICYD_DATABASE_USER}'@'localhost' IDENTIFIED BY '${CBPOLICYD_PWD}'; 
GRANT ALL PRIVILEGES ON ${CBPOLICYD_DATABASE} . * TO '${CBPOLICYD_DATABASE_USER}'@'localhost' WITH GRANT OPTION; 
FLUSH PRIVILEGES ; 
EOF

  su - zimbra -c "${ZIMBRA_MYSQL_BINARY}" < "${CBPOLICYD_DBCREATE_TMP_SQL}"
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

  su - zimbra -c "${ZIMBRA_MYSQL_BINARY} ${CBPOLICYD_DATABASE}" < "${CBPOLICYD_CONTENTS_TMP_SQL}"
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

su - zimbra -c "${ZIMBRA_MYSQL_BINARY} ${CBPOLICYD_DATABASE}" < "${CBPOLICYD_POLICY_SQL}"
}

function reporting_commands_install () {
  echo "su - zimbra -c \"${ZIMBRA_MYSQL_BINARY} ${CBPOLICYD_DATABASE} -e 'select count(instance) count, sender from session_tracking where date(from_unixtime(unixtimestamp))=curdate() group by sender order by count desc;'\"" > /usr/local/sbin/cbpolicyd-report
  chmod +rx /usr/local/sbin/cbpolicyd-report
}

function dig_requisite() {
  if [[ "$IS_SINGLE" == "TRUE" ]] ; then
    :
  else
  # Detect dig
    if ! command -v dig 2>&1 >/dev/null
    then
      echo "The program needs 'dig'."
      echo "You might need to install dnsutils package in Ubuntu."
      echo "Aborting..."
      exit 1
    fi
  fi
}

function mailbox_check () {
  MAILBOX_FOUND="FALSE"

  for nserver in $(su - zimbra -c 'zmprov -l getAllServers mailbox'); do
    if [[ "$nserver" == "${ZMHOSTNAME}" ]] ; then
      MAILBOX_FOUND="TRUE"
    fi
  done

  if [[ "${MAILBOX_FOUND}" == "TRUE" ]] ; then
    :
  else
    echo "This node needs to be a mailbox!"
    echo "Aborting..."
    exit 1
  fi
}

# Main program

# Check the arguments.
for option in "$@"; do
  case "$option" in
    -h | --help)
      usage
      exit 0
    ;;
    --single)
      IS_SINGLE="TRUE"
    ;;
  esac
done

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Definitions

ZIMBRA_MYSQL_BINARY="mysql"

CBPOLICYD_PWD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 10)
CBPOLICYD_DATABASE_USER='ad-policyd_db'
CBPOLICYD_DATABASE='policyd_db'

CBPOLICYD_DBCREATE_TMP_SQL="$(mktemp /tmp/policyd-dbcreate.XXXXXXXX.sql)"
CBPOLICYD_CONTENTS_TMP_SQL="$(mktemp /tmp/policyd-dbtables.XXXXXXXX.sql)"
CBPOLICYD_POLICY_SQL="$(mktemp /tmp/policyd-policy.XXXXXXXX.sql)"

ZMHOSTNAME="$(su - zimbra -c 'zmhostname')"

dig_requisite
mailbox_check

create_cbpolicyd_db_and_user # "Creating database and user"
populate_cbpolicyd_databases # Populating databases
# add_zimbra_policy # Setting basic quota policy
# reporting_commands_install # Installing reporting commands

if [[ "$IS_SINGLE" == "TRUE" ]] ; then
  :
else
  CBPOLICYD_DB_HOST="$(dig +short ${ZMHOSTNAME} A)"

  cat << EOF
To be run on every MTA node:

./cbpolicyd-mta-installer.sh --db-host='${CBPOLICYD_DB_HOST}' --db-password='${CBPOLICYD_PWD}'
EOF
fi
