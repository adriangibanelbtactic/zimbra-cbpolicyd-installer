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
Automated cbpolicyd installer for Zimbra mta node.

- No webui is installed.
- Aimed at Zimbra 10.0.x

Usage:   $0 --db-host=CBPOLICYD_DATABASE_HOST --db-password=CBPOLICYD_DATABASE_PASSWORD
Example: $0 --db-host=127.0.0.1 --db-password=Mys3cr3t
EOF
}

function update_cbpolicyd_conf_in_settings () {
  cp -a ${CBPOLICYD_CONF_IN} ${CBPOLICYDCONF_TMP_BACKUP} # Backing up cbpolicyd.conf.in
  grep -lZr -e ".*sername=.*$" "${CBPOLICYD_CONF_IN}" | xargs -0 sed -i "s^.*sername=.*$^Username=${CBPOLICYD_DATABASE_USER}^g"
  grep -lZr -e ".*assword=.*$" "${CBPOLICYD_CONF_IN}"  | xargs -0 sed -i "s^.*assword=.*$^Password=${CBPOLICYD_PWD}^g"
  grep -lZr -e "DSN=.*$" "${CBPOLICYD_CONF_IN}"  | xargs -0 sed -i "s^DSN=.*$^DSN=DBI:mysql:database=${CBPOLICYD_DATABASE};host=${CBPOLICYD_DB_HOST};port=7306^g"
}

function cron_setup () {
  if [[ -x "/opt/zimbra/common/bin/cbpadmin" ]]
  then
    echo "35 3 * * * zimbra bash -l -c '/opt/zimbra/common/bin/cbpadmin --config=/opt/zimbra/conf/cbpolicyd.conf --cleanup' >/dev/null" > "${CBPOLICYD_CLEANUP_CRON_FILE}"
  else
    echo "WARNING: cbpadmin is not found in /opt/zimbra. Cleanup cron was not installed!" 
  fi
}

function mta_check () {
  MTA_FOUND="FALSE"

  for nserver in $(su - zimbra -c 'zmprov -l getAllServers mta'); do
    if [[ "$nserver" == "${ZMHOSTNAME}" ]] ; then
      MTA_FOUND="TRUE"
    fi
  done

  if [[ "${MTA_FOUND}" == "TRUE" ]] ; then
    :
  else
    echo "This node needs to be a mta!"
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
    --db-host=*)
      CBPOLICYD_DB_HOST=`echo "$option" | sed 's/--db-host=//'`
    ;;
    --db-password=*)
      CBPOLICYD_PWD=`echo "$option" | sed 's/--db-password=//'`
    ;;
  esac
done

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [[ "x$CBPOLICYD_PWD" == x ]] ; then
  usage
  exit 1
fi

if [[ "x$CBPOLICYD_DB_HOST" == x ]] ; then
  usage
  exit 1
fi

# Definitions

ZIMBRA_MYSQL_BINARY="/opt/zimbra/bin/mysql"

CBPOLICYD_DATABASE_USER='ad-policyd_db'
CBPOLICYD_DATABASE='policyd_db'

CBPOLICYDCONF_TMP_BACKUP="$(mktemp /tmp/cbpolicyd.conf.in.XXXXXXXX)"
CBPOLICYD_CONF_IN='/opt/zimbra/conf/cbpolicyd.conf.in'

ZMHOSTNAME="$(su - zimbra -c 'zmhostname')"

mta_check

update_cbpolicyd_conf_in_settings # Update username, password and database on cbpolicyd.conf.in
cron_setup # Setting up cron
