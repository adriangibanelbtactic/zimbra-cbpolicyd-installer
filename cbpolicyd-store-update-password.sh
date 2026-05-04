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
Update cbpolicyd database password for Zimbra mailbox node.

Usage:   $0
Example: $0
EOF
}

for option in "$@"; do
  case "$option" in
    -h | --help)
      usage
      exit 0
    ;;
    *)
      usage
      exit 1
    ;;
  esac
done

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

ZIMBRA_MYSQL_BINARY="mysql"
CBPOLICYD_DATABASE_USER='ad-policyd_db'
CBPOLICYD_PWD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 10)

CBPOLICYD_DBPWD_TMP_SQL="$(mktemp /tmp/policyd-dbpwd.XXXXXXXX.sql)"

cat <<EOF > "${CBPOLICYD_DBPWD_TMP_SQL}"
ALTER USER IF EXISTS '${CBPOLICYD_DATABASE_USER}'@'%' IDENTIFIED BY '${CBPOLICYD_PWD}';
ALTER USER IF EXISTS '${CBPOLICYD_DATABASE_USER}'@'localhost' IDENTIFIED BY '${CBPOLICYD_PWD}';
FLUSH PRIVILEGES;
EOF

su - zimbra -c "${ZIMBRA_MYSQL_BINARY}" < "${CBPOLICYD_DBPWD_TMP_SQL}"

rm "${CBPOLICYD_DBPWD_TMP_SQL}"

cat << EOF
Generated new CBPolicyD database password:

${CBPOLICYD_PWD}

Run on every MTA node:

./cbpolicyd-mta-update-password.sh --db-host='CBPOLICYD_DATABASE_HOST' --db-password='${CBPOLICYD_PWD}'
EOF
