# CBPolicyD Installer

Aimed at MTA nodes and MAILBOX nodes.
Every MTA will share the same CBPolicyD config which will be stored on only one mailbox server.

## About

**WARNING: The development stage is in ALPHA QUALITY and it is not ready for production deployment.**

## Single server install

Use `./cpolicyd-store-installer.sh` first which will output the suggested mta installer prompt which you will have to run.

Example:
```
TODO
```

Finally turn on CBPolicyD by running:
```
zmprov ms $(zmhostname) +zimbraServiceEnabled cbpolicyd
zmprov ms $(zmhostname) zimbraCBPolicydQuotasEnabled TRUE
```

## Multi server install

### Steps

1. On one of the Zimbra mailbox nodes use `./cpolicyd-store-installer.sh` first which will output the suggested mta installer prompt which you will have to run.

2. On the same Zimbra mailbox edit `/opt/zimbra/conf/my.cnf` and replace `bind-address = 127.0.0.1` with `bind-address = 0.0.0.0`.
**Warning**: If this mailbox is somehow directly exposed to the Internet you will have to harden the 7306 port thanks to some Firewall rules.

Make sure that you restart mailbox service with `su - zimbra -c 'zmmailboxdctl restart'` so that the new settings are applied.

3. On every Zimbra mta node use the suggested mta installer prompt.
4. On every Zimbra mta node turn on CBPolicyD by running:
```
zmprov ms $(zmhostname) +zimbraServiceEnabled cbpolicyd
zmprov ms $(zmhostname) zimbraCBPolicydQuotasEnabled TRUE
```

### Mailbox - Multi server install example

```
cd /tmp
git clone https://github.com/btactic/zimbra-cbpolicyd-installer.git
cd zimbra-cbpolicyd-installer

sudo ./cbpolicyd-store-installer.sh
```

At this point write down the suggested command.

As an optional step you can edit default policies.

```
su - zimbra
mysql policyd_db
# Edit policies with mysql
exit
```

Finally edit my.cnf to allow remote connections:
```
vim  /opt/zimbra/conf/my.cnf
# Replace `bind-address = 127.0.0.1` with `bind-address = 0.0.0.0`.

su - zimbra -c 'zmmailboxdctl restart'
```

### MTA - Multi server install example

```
cd /tmp
git clone https://github.com/btactic/zimbra-cbpolicyd-installer.git
cd zimbra-cbpolicyd-installer
```
Now run the suggested command from the mailbox output:
```
sudo ./cbpolicyd-mta-installer.sh --db-host='192.168.0.200' --db-password='i7xO7ov88G'
```
.

Finally turn on CBPolicyD:
```
su - zimbra -c 'zmprov ms $(zmhostname) +zimbraServiceEnabled cbpolicyd'
su - zimbra -c 'zmprov ms $(zmhostname) zimbraCBPolicydQuotasEnabled TRUE'
```

## Mailbox notes

- Database clean-up is scheduled daily at 03:35AM using: `/etc/cron.d/zimbra-cbpolicyd-cleanup`
- On Zimbra patches and upgrades, you may need to re-run these scripts or re-apply the configuration
- You can change or review your polcies using mysql client:
```
/opt/zimbra/bin/mysql policyd_db
SELECT * FROM quotas_limits;
UPDATE quotas_limits SET CounterLimit = 30 WHERE ID = 4;
```

## MTA notes

- You can check CBPolicyD logs by running:
```
tail -f /opt/zimbra/log/cbpolicyd.log
```
.

- You can modify some settings at `/opt/zimbra/conf/cbpolicyd.conf.in`.

- Make sure to comment `::1 localhost` line in `/etc/hosts` if your VPS is IPv4 only.

## Credits

These scripts are based mainly on [https://github.com/Zimbra-Community/zimbra-tools/blob/master/cbpolicyd.sh] originally made by Barry De Graaff.
