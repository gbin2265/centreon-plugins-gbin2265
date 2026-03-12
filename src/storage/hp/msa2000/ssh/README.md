# HPE MSA 2060 / MSA 2000 - Centreon Plugin

## Description

Centreon plugin to monitor HPE MSA 2060 (and compatible MSA 2000 series) storage arrays via SSH.
The MSA CLI returns XML output which is parsed by this plugin.

Package: `storage::hp::msa2000::ssh`

## Prerequisites

- SSH access to the MSA storage array (user with `monitor` or `manage` role)
- Perl SSH backend: `libssh` (recommended), `plink`, or SSH key authentication with `sshcli`

```bash
# Test libssh availability
perl -e "use Libssh::Session; print 'OK\n'"
```

## Usage

```bash
/usr/lib/centreon/plugins/centreon_plugins.pl \
  --plugin=storage::hp::msa2000::ssh::plugin \
  --custommode=ssh \
  --hostname=<MSA_IP> \
  --ssh-username=<USER> \
  --ssh-password=<PASS> \
  --ssh-backend=libssh \
  --mode=<MODE>
```

## Available Modes

| Mode | SSH Command(s) | Description | Perfdata |
|---|---|---|---|
| system | show system | Overall system health, unhealthy components | - |
| controllers | show controllers + show controller-statistics | Controller health, CPU, cache, IO stats | cpu-util, read/write throughput, cache-hits, iops |
| disks | show disks + show disk-statistics | Disk health, SMART, IO stats | temperature, power-on-hours, errors, iops, throughput, smart-events, media-errors, bad-blocks, io-timeouts |
| disk-groups | show disk-groups + show disk-group-statistics | Disk group health, RAID, capacity, IO stats | usage, iops, throughput, response-times |
| enclosures | show enclosure | Enclosure health, model, component count | power (W) |
| fans | show fans | Fan health, location | speed (RPM) |
| ntp-status | show ntp-status | NTP sync status, server, contact time | - |
| pools | show pools + show pool-statistics | Pool health, capacity, page allocation stats | usage, pages-alloc/dealloc/unmap, hot/cold-page-moves |
| ports | show ports + show host-port-statistics | Port health, link status, IO stats | iops, throughput, response-times, queue-depth |
| psu | show power-supplies + show sensor-status | PSU health, temperature, voltage, current | temperature (C), voltage (V), current (A) |
| redundancy | show redundancy-mode | Controller redundancy status and mode | - |
| sensors | show sensor-status | Temperature, voltage, current sensors | temperature (C), voltage (V), current (A) |
| shutdown-status | show shutdown-status | Controller shutdown state | - |
| uptime | show controller-statistics | Controller uptime and total power-on time | uptime (s), total-power-on (s) |
| versions | show versions | Firmware versions, mismatch check between controllers | - |
| volumes | show volumes + show volume-statistics | Volume health, capacity, IO stats | usage, iops, throughput, response-times |

## Default Thresholds

Health status checks use the following defaults:

- **CRITICAL**: degraded, fault, failed, error, off
- **UNKNOWN**: unknown

These can be overridden per mode with `--warning-status` and `--critical-status`.

## Filter Options

Most modes support `--filter-<name>` and `--exclude-<name>` options (regexp-based) to select specific components.

## Compatibility

| Model | Status |
|---|---|
| MSA 2060 | Fully tested |
| MSA 2050 | Should work without modifications (same firmware generation) |
| MSA 2040 | Likely works with limitations (older firmware, no pools) |

## Files

```
storage/hp/msa2000/ssh/
├── plugin.pm                  # Plugin registration (16 modes)
├── custom/
│   └── custom.pm              # SSH custom mode (XML parser)
└── mode/
    ├── controllers.pm
    ├── diskgroups.pm
    ├── disks.pm
    ├── enclosures.pm
    ├── fans.pm
    ├── ntpstatus.pm
    ├── pools.pm
    ├── ports.pm
    ├── powersupplies.pm
    ├── redundancy.pm
    ├── sensors.pm
    ├── shutdownstatus.pm
    ├── system.pm
    ├── uptime.pm
    ├── versions.pm
    └── volumes.pm
```

## License

Copyright 2026 Centreon - Apache License 2.0
