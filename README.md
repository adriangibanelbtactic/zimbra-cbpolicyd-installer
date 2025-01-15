# CBPolicyD Installer

Aimed at MTA nodes and MAILBOX nodes.
Every MTA will share the same CBPolicyD config which will be stored on only one mailbox server.

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

On one of the Zimbra mailbox nodes use `./cpolicyd-store-installer.sh` first which will output the suggested mta installer prompt which you will have to run.

On every Zimbra mta node use the suggested mta installer prompt.
On every Zimbra mta node turn on CBPolicyD by running:
```
zmprov ms $(zmhostname) +zimbraServiceEnabled cbpolicyd
zmprov ms $(zmhostname) zimbraCBPolicydQuotasEnabled TRUE
```

Example:
```
TODO
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

You can check CBPolicyD logs by running:
```
tail -f /opt/zimbra/log/cbpolicyd.log
```
.

## Credits

These scripts are based mainly on [https://github.com/Zimbra-Community/zimbra-tools/blob/master/cbpolicyd.sh] originally made by Barry De Graaff.
