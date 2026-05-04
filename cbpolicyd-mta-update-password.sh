#!/bin/bash

# Copyright (C) 2026 BTACTIC, S.C.C.L.
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

function usage () {
cat << EOF
Update cbpolicyd password settings for Zimbra mta node.

Usage:   $0 --db-host=CBPOLICYD_DATABASE_HOST --db-password=CBPOLICYD_DATABASE_PASSWORD
Example: $0 --db-host=127.0.0.1 --db-password=Mys3cr3t
EOF
}

function update_cbpolicyd_conf_in_settings () {
  cp -a ${CBPOLICYD_CONF_IN} ${CBPOLICYDCONF_TMP_BACKUP}
  grep -lZr -e ".*sername=.*$" "${CBPOLICYD_CONF_IN}" | xargs -0 sed -i "s^.*sername=.*$^Username=${CBPOLICYD_DATABASE_USER}^g"
  grep -lZr -e ".*assword=.*$" "${CBPOLICYD_CONF_IN}"  | xargs -0 sed -i "s^.*assword=.*$^Password=${CBPOLICYD_PWD}^g"
  grep -lZr -e "DSN=.*$" "${CBPOLICYD_CONF_IN}"  | xargs -0 sed -i "s^DSN=.*$^DSN=DBI:mysql:database=${CBPOLICYD_DATABASE};host=${CBPOLICYD_DB_HOST};port=7306^g"
}

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

CBPOLICYD_DATABASE_USER='ad-policyd_db'
CBPOLICYD_DATABASE='policyd_db'

CBPOLICYDCONF_TMP_BACKUP="$(mktemp /tmp/cbpolicyd.conf.in.XXXXXXXX)"
CBPOLICYD_CONF_IN='/opt/zimbra/conf/cbpolicyd.conf.in'

update_cbpolicyd_conf_in_settings
