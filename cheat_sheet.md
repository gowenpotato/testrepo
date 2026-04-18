---
title: Linux & Bash Cheat Sheet
---

# Linux & Bash Cheat Sheet

A personal reference covering bash scripting, Linux internals, and networking.

---

## Module 1 — Bash Scripting

### Parameter Expansion

```bash
# Basename and dirname without commands
path="/var/log/nginx/access.log"
echo "${path##*/}"          # access.log        (strip longest prefix up to /)
echo "${path%/*}"           # /var/log/nginx     (strip shortest suffix from /)

# Defaults
echo "${var:-default}"      # use default if var unset/empty, var unchanged
echo "${var:=default}"      # assign default if var unset/empty, var changed
echo "${var:?error msg}"    # exit with error if var unset/empty
echo "${var:+alt}"          # return alt only if var IS set

# Substrings
echo "${var:0:5}"           # chars 0-4
echo "${var: -5}"           # last 5 chars (note space before -)
echo "${#var}"              # length of var

# Strip patterns
echo "${var#pattern}"       # strip shortest match from front
echo "${var##pattern}"      # strip longest match from front
echo "${var%pattern}"       # strip shortest match from end
echo "${var%%pattern}"      # strip longest match from end

# Replace
echo "${var/old/new}"       # replace first match
echo "${var//old/new}"      # replace all matches
echo "${var/#old/new}"      # replace at start only
echo "${var/%old/new}"      # replace at end only

# Case
echo "${var^^}"             # uppercase all
echo "${var^}"              # uppercase first char
echo "${var,,}"             # lowercase all

# Indirect expansion
name="alice"
alice="green"
echo "${!name}"             # green — expand variable whose name is in $name

# List variable names matching prefix
echo "${!DB_*}"             # all vars starting with DB_
```

---

### Arrays

```bash
# Indexed arrays
arr=("apple" "banana" "cherry")
echo "${arr[0]}"            # apple
echo "${arr[@]}"            # all elements
echo "${#arr[@]}"           # count
echo "${!arr[@]}"           # indices: 0 1 2
echo "${arr[@]:1:2}"        # slice: banana cherry

# Append
arr+=("date")

# Remove element (leaves gap)
unset 'arr[1]'

# Re-index to close gaps
arr=("${arr[@]}")

# Loop — always quote [@]
for item in "${arr[@]}"; do
    echo "$item"
done

# Associative arrays
declare -A config=(
    [host]="localhost"
    [port]="5432"
)
echo "${config[host]}"
for key in "${!config[@]}"; do
    echo "$key = ${config[$key]}"
done
```

---

### Process Substitution

```bash
# Feed command output as a file — fixes subshell variable problem
while IFS= read -r line; do
    (( count++ ))
done < <(cat /etc/passwd)
echo "$count"               # works — no subshell

# Diff two commands without temp files
diff <(ls /etc) <(ls /usr/lib)

# Feed output into two processors simultaneously
tee >(grep ERROR > errors.log) >(grep WARN > warnings.log) < app.log

# Log and display simultaneously
some_command > >(tee output.log) 2> >(tee errors.log >&2)

# Coprocess — two-way conversation with a background process
coproc BC { bc -l; }
echo "3.14159 * 2" >&${BC[1]}
read result <&${BC[0]}
echo "$result"
kill $BC_PID
```

---

### trap & Signals

```bash
# Signals
# EXIT   — fires on any exit (not a real signal)
# INT    — Ctrl-C
# TERM   — kill <pid>
# HUP    — terminal closed
# KILL   — kill -9 (cannot be trapped)
# ERR    — any non-zero exit code

# Basic trap
trap 'rm -f /tmp/lockfile' EXIT

# Cleanup function pattern
cleanup() {
    local exit_code=$?          # capture immediately before anything overwrites it
    rm -f "$lockfile"
    rm -rf "$tmpdir"
    [[ $exit_code -ne 0 ]] && echo "failed with code $exit_code" >&2
    exit $exit_code
}
trap cleanup EXIT

# Different behaviour per signal
interrupted() { echo "interrupted" >&2; cleanup; exit 130; }
trap cleanup EXIT
trap interrupted INT TERM

# ERR trap for debugging
trap 'echo "error on line $LINENO" >&2' ERR

# Reset a trap
trap - EXIT

# Exit codes by convention
# 0    success
# 1    general error
# 130  killed by Ctrl-C (128 + 2)
```

---

### sed

```bash
# Structure: sed 'ADDRESS COMMAND' file
# Address: line number, range, or /pattern/
# Command: d (delete), p (print), s (substitute)

# Outer flags
# -n    suppress default output
# -i    edit in place
# -i.bak  edit in place with backup
# -E    extended regex (enables + ? | without escaping)

# Inner flags (after last / in substitution)
# g     replace all matches
# p     print if substitution made
# I     case insensitive
# 2     replace second match only

# Common patterns
sed 's/old/new/g' file                  # replace all
sed 's/old/new/2' file                  # replace second occurrence
sed -n '/pattern/p' file                # print matching lines (like grep)
sed '/pattern/d' file                   # delete matching lines
sed '/pattern/!d' file                  # delete non-matching lines (keep matches)
sed '3d' file                           # delete line 3
sed '3,5d' file                         # delete lines 3-5
sed -n '3,5p' file                      # print lines 3-5
sed '/start/,/end/d' file               # delete between patterns
sed '1~2d' file                         # delete every other line (start=1, step=2)
sed '/alice/s/london/edinburgh/' file   # substitute only on matching lines
sed -E 's/(first) (second)/\2 \1/' file # swap capture groups
sed -E 's/[^0-9]*//' file              # strip non-numeric prefix

# Multiline
sed 'N; s/\n/ /' file                  # join pairs of lines
sed -n '/ERROR/{n;p}' file             # print line after ERROR
```

---

### awk

```bash
# Structure: awk 'pattern { action } END { action }' file
# pattern  — which lines to act on (empty = all lines)
# action   — what to do
# END      — runs once after all lines

# Built-in variables
# NR       current line number
# NF       number of fields on current line
# $0       whole line
# $1..$NF  individual fields
# FS       field separator (default: whitespace)
# OFS      output field separator

# Field separator
awk -F: '{print $1}' /etc/passwd        # colon separated
awk -F', ' '{print $1}' file            # multi-char separator
awk 'BEGIN{FS=":"} {print $1}' file     # set in BEGIN block

# Common patterns
awk '{print $2}' file                   # print field 2
awk 'NR > 1 {print}' file              # skip header line
awk '$3 == "ERROR" {print}' file        # filter by field value
awk '$5 > 1000 {print $2, $5}' file    # numeric filter
awk '/pattern/ {print}' file            # regex filter
awk '$0 ~ var {print}' file            # match line against variable

# Accumulation
awk '{sum += $5} END {print sum}' file
awk 'END {print NR}' file               # line count
awk '$3 == "ERROR" {c++} END {print c+0}' file

# Associative arrays
awk '{counts[$1]++} END {for (k in counts) print counts[k], k}' file
awk '{bytes[$2] += $5} END {for (k in bytes) print k, bytes[k]}' file

# Pass shell variables in
awk -v thresh="$threshold" '$5 > thresh {print}' file

# Printf formatting
awk '{printf "%-20s %d\n", $1, $2}' file

# Multiple patterns
awk '/START/,/END/ {print}' file        # between two patterns
awk 'NR==1{header=$0} NR>1{print}' file # store header, process rest
```

---

### Here-docs & Here-strings

```bash
# Here-doc — multiline input to a command
cat << EOF
Hello $USER
Today is $(date)
EOF

# Quoted EOF — no expansion, literal text
cat << 'EOF'
Hello $USER        # prints literally, not expanded
EOF

# Indented — strips leading tabs (not spaces)
cat <<- EOF
	indented content
	EOF

# Write to a file
cat > /tmp/config.txt << EOF
host=$hostname
port=5432
EOF

# Append to a file
cat >> /tmp/config.txt << EOF
user=admin
EOF

# Write to privileged location
sudo tee /etc/myconfig << EOF
setting=value
EOF

# Here-string — single string to stdin
read -r a b c <<< "one two three"
result=$(bc <<< "3.14 * 2")
grep -q "ERROR" <<< "$line" && echo "found"
```

---

### Script Hardening

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# set -e   exit on any non-zero exit code
# set -u   unset variables are errors
# set -o pipefail   pipeline fails if any command fails
# IFS=$'\n\t'   removes space as field separator

# set -e gotchas
if grep -q "pattern" file; then    # exempt — if conditions don't trigger -e
    echo "found"
fi
grep -q "pattern" file || echo "not found"   # exempt — last command in ||

# set -u with optional vars
[[ "${1:-}" == "verbose" ]] && verbose=true   # safe — default to empty

# readonly — prevent accidental overwrite
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="${0##*/}"

# Production template
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="${0##*/}"
readonly LOG_FILE="/tmp/${SCRIPT_NAME}.log"

log()  { echo "$(date '+%Y-%m-%d %H:%M:%S') INFO  $*" | tee -a "$LOG_FILE"; }
warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') WARN  $*" | tee -a "$LOG_FILE" >&2; }
die()  { echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR $*" | tee -a "$LOG_FILE" >&2; exit 1; }

cleanup() {
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && warn "exited with code $exit_code"
}
trap cleanup EXIT

main() {
    # your code here
}

main "$@"
```

---

### [[ ]] Tests & Conditionals

```bash
# File tests
[[ -f "$file" ]]    # exists and is a regular file
[[ -d "$dir" ]]     # exists and is a directory
[[ -e "$path" ]]    # exists (any type)
[[ -L "$path" ]]    # is a symlink
[[ -r "$file" ]]    # readable
[[ -w "$file" ]]    # writable
[[ -x "$file" ]]    # executable
[[ -s "$file" ]]    # exists and non-empty

# String tests
[[ -z "$str" ]]             # empty
[[ -n "$str" ]]             # non-empty
[[ "$a" == "$b" ]]          # equal
[[ "$a" != "$b" ]]          # not equal
[[ "$str" == *.log ]]       # glob match (right side unquoted)
[[ "$str" =~ ^[0-9]+$ ]]    # regex match (right side unquoted)

# Numeric tests
[[ "$a" -eq "$b" ]]    # equal
[[ "$a" -ne "$b" ]]    # not equal
[[ "$a" -lt "$b" ]]    # less than
[[ "$a" -gt "$b" ]]    # greater than
[[ "$a" -le "$b" ]]    # less than or equal
[[ "$a" -ge "$b" ]]    # greater than or equal

# Combining
[[ condition1 && condition2 ]]
[[ condition1 || condition2 ]]
[[ ! condition ]]

# Arithmetic with (( ))
(( count > 3 )) && echo "big"
(( count++ ))
(( total = a + b ))

# Common patterns
[[ -f "$file" ]] || { echo "not found" >&2; exit 1; }
[[ -d "$dir" ]] || mkdir -p "$dir"
[[ "$input" =~ ^[0-9]+$ ]] || { echo "not a number" >&2; exit 1; }
[[ -x "$(command -v docker)" ]] || die "docker not installed"
```

---

### File Descriptors & Redirects

```bash
# Default file descriptors
# 0   stdin
# 1   stdout
# 2   stderr

command > file          # fd 1 → file
command 2> file         # fd 2 → file
command >> file         # fd 1 → file (append)
command > file 2>&1     # both to file (correct order)
command 2>&1 > file     # wrong — stderr to terminal, stdout to file
command &> file         # shorthand for both to file
command > /dev/null     # discard stdout
command 2> /dev/null    # discard stderr
command &> /dev/null    # discard everything
```

---

## Module 2 — Linux Internals

### Boot Process

```
Power → UEFI firmware → GRUB → Kernel → initramfs → systemd → userspace
```

```bash
# Check UEFI or BIOS
ls /sys/firmware/efi 2>/dev/null && echo "UEFI" || echo "BIOS"

# Kernel command line passed by GRUB
cat /proc/cmdline

# Kernel messages from boot
dmesg -T | head -50
dmesg -T | grep -iE "error|warn"

# Boot time breakdown
systemd-analyze
systemd-analyze blame | head -10
systemd-analyze critical-chain
systemd-analyze plot > /tmp/boot.svg    # visual timeline

# GRUB config — edit this, not grub.cfg
sudo vim /etc/default/grub
sudo update-grub

# EFI boot entries
efibootmgr -v
```

---

### systemd Units

```bash
# Unit file locations
# /lib/systemd/system/    package defaults — don't edit
# /etc/systemd/system/    your overrides — edit here

# Managing units
sudo systemctl start|stop|restart|reload unit.service
sudo systemctl enable|disable unit.service
sudo systemctl enable --now unit.service    # enable and start
sudo systemctl status unit.service
sudo systemctl daemon-reload                # after editing unit files

# Inspecting
systemctl list-units --type=service
systemctl list-unit-files
systemctl cat unit.service
systemctl show unit.service -p Property1,Property2
journalctl -u unit.service -b              # logs for this boot
journalctl -f                              # follow live

# Targets
systemctl get-default
sudo systemctl set-default multi-user.target
sudo systemctl isolate rescue.target        # switch now
systemctl list-dependencies graphical.target

# Unit file structure
[Unit]
Description=My service
After=network.target            # ordering only
Requires=postgresql.service     # hard dependency
Wants=redis.service             # soft dependency

[Service]
Type=simple|forking|oneshot|notify
User=myuser
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/server
ExecReload=/bin/kill -HUP $MAINPID
Restart=always|on-failure|no
RestartSec=5
Environment=KEY=value
EnvironmentFile=/etc/myapp/env

[Install]
WantedBy=multi-user.target

# Write unit file safely
sudo tee /etc/systemd/system/myapp.service << 'EOF'
[Unit]
...
EOF

# Set resource limits without editing unit file
sudo systemctl set-property myapp.service MemoryMax=512M
sudo systemctl set-property myapp.service CPUQuota=25%

# Timer unit
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
OnCalendar=daily
Unit=myapp.service

[Install]
WantedBy=timers.target

systemctl list-timers
```

---

### /proc & /sys

```bash
# /proc — process and kernel information (virtual filesystem)
cat /proc/cmdline               # kernel command line
cat /proc/version               # kernel version
cat /proc/meminfo               # memory details
cat /proc/cpuinfo               # CPU details
cat /proc/loadavg               # load averages
cat /proc/uptime                # seconds since boot
cat /proc/mounts                # mounted filesystems
cat /proc/net/dev               # network interface stats

# Per-process info
cat /proc/$$/cmdline | tr '\0' ' '
cat /proc/$$/status             # memory, threads, uid
ls /proc/$$/fd/                 # open file descriptors
cat /proc/$$/cgroup             # which cgroup

# /proc/sys — runtime kernel tuning (temporary, resets on reboot)
cat /proc/sys/vm/swappiness
echo 10 > /proc/sys/vm/swappiness
cat /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/ip_forward

# sysctl — permanent changes
sudo sysctl -w vm.swappiness=10
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-custom.conf
sudo sysctl -p /etc/sysctl.d/99-custom.conf

# /sys — kernel device model
ls /sys/class/net/                                  # network interfaces
cat /sys/class/net/eth0/address                     # MAC address
cat /sys/block/nvme0n1/size                         # disk size in sectors
cat /sys/block/nvme0n1/queue/scheduler              # I/O scheduler
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

---

### Kernel Modules

```bash
lsmod                           # list loaded modules
modinfo module_name             # info about a module
sudo modprobe module_name       # load (with dependencies)
sudo modprobe -r module_name    # unload
sudo depmod -a                  # rebuild dependency map

# Load at boot
echo "module_name" | sudo tee /etc/modules-load.d/mymodule.conf

# Module parameters at boot
echo "options usbcore autosuspend=-1" | sudo tee /etc/modprobe.d/usb.conf

# Blacklist a module
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist.conf

# After blacklisting — rebuild initramfs
sudo update-initramfs -u

# Hardware → module mapping
lspci -k                        # PCI devices and their drivers
lsusb                           # USB devices
```

---

### Memory

```bash
free -h
cat /proc/meminfo | grep -E "MemTotal|MemAvailable|SwapFree|Cached"

# MemFree      — completely unused RAM
# MemAvailable — free + reclaimable cache (the real number to watch)
# Cached       — file cache — can be reclaimed
# SwapFree     — if this is low, you're in trouble

# OOM killer
sudo dmesg | grep -i "oom\|killed process"
cat /proc/PID/oom_score
echo -1000 | sudo tee /proc/PID/oom_score_adj    # protect from OOM

# Swappiness
cat /proc/sys/vm/swappiness     # default 60
# 0 = avoid swap, 100 = swap aggressively
# desktop: 10, database server: 1

# Hugepages
cat /proc/meminfo | grep -i huge
echo 512 | sudo tee /proc/sys/vm/nr_hugepages
cat /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

---

### cgroups v2 & Namespaces

```bash
# cgroups — control resource usage
# namespaces — control visibility (isolation)
# container = cgroups + namespaces + root filesystem

# Check cgroup version
mount | grep cgroup
ls /sys/fs/cgroup/

# systemd cgroup tools
systemd-cgls                    # cgroup tree
systemd-cgtop                   # live resource usage

# Set limits on a service
sudo systemctl set-property myapp.service MemoryMax=512M
sudo systemctl set-property myapp.service CPUQuota=25%
sudo systemctl set-property myapp.service TasksMax=50

# Direct cgroup manipulation
sudo mkdir /sys/fs/cgroup/mygroup
echo $((256 * 1024 * 1024)) | sudo tee /sys/fs/cgroup/mygroup/memory.max
echo "50000 100000" | sudo tee /sys/fs/cgroup/mygroup/cpu.max   # 50% of one core
echo $$ | sudo tee /sys/fs/cgroup/mygroup/cgroup.procs

# Namespace types
# pid    process IDs
# net    network stack
# mnt    filesystem mounts
# uts    hostname
# ipc    inter-process communication
# user   user/group IDs
# cgroup cgroup root

# See process namespaces
ls -la /proc/$$/ns/

# unshare — create new namespace
sudo unshare --uts bash                         # isolated hostname
sudo unshare --pid --fork --mount-proc bash     # isolated PID tree
sudo unshare --net bash                         # isolated network
sudo unshare --pid --net --mnt --uts --ipc --fork --mount-proc bash  # all

# nsenter — enter existing namespace (how docker exec works)
sudo nsenter -t PID --all bash
sudo nsenter -t PID --net bash      # just network namespace
sudo nsenter -t PID --net ip link   # run single command
```

---

## Module 3 — Networking

### Netfilter Architecture

```
Incoming packet
      │
      ▼
 PREROUTING    ← nat (DNAT), mangle, raw
      │
      ▼
 Routing decision
      │
      ├── local process ──→ INPUT ──→ filter, mangle
      │
      └── forward ────────→ FORWARD ──→ filter, mangle
                                │
                                ▼
                          POSTROUTING ← nat (SNAT/MASQUERADE), mangle
```

Tables and their hooks:

| Table | Hooks |
|-------|-------|
| filter | INPUT, FORWARD, OUTPUT |
| nat | PREROUTING, OUTPUT, POSTROUTING |
| mangle | all five hooks |
| raw | PREROUTING, OUTPUT |

---

### iptables

```bash
# List rules
sudo iptables -L -v -n --line-numbers
sudo iptables -t nat -L -v -n

# Add rules
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT       # append
sudo iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT     # insert at position 1

# Delete rules
sudo iptables -D INPUT 3                                  # by line number
sudo iptables -D INPUT -p tcp --dport 22 -j ACCEPT        # by spec

# Default policies
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Flush
sudo iptables -F
sudo iptables -t nat -F

# Common matches
-p tcp|udp|icmp
--dport 80
--sport 1024:65535
-s 192.168.1.0/24
-d 10.0.0.1
-i eth0                              # incoming interface
-o eth0                              # outgoing interface
-m state --state ESTABLISHED,RELATED
-m multiport --dports 80,443

# Targets
-j ACCEPT
-j DROP                              # silent discard
-j REJECT                            # send ICMP error back
-j LOG --log-prefix "dropped: "
-j MASQUERADE
-j DNAT --to-destination 192.168.1.10:80
-j SNAT --to-source 1.2.3.4

# NAT — port forwarding
sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 \
    -j DNAT --to-destination 192.168.1.10:80
sudo iptables -A FORWARD -p tcp -d 192.168.1.10 --dport 80 -j ACCEPT
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Masquerade — share internet connection
sudo iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE

# Save and restore
sudo iptables-save > /etc/iptables/rules.v4
sudo iptables-restore < /etc/iptables/rules.v4
```

---

### nftables

```bash
# Basic commands
sudo nft list ruleset
sudo nft list ruleset -a            # with handles for deletion
sudo nft add table inet myfirewall
sudo nft delete table inet myfirewall
sudo nft flush ruleset
sudo nft -f /etc/nftables.conf      # load from file
sudo systemctl enable nftables

# Rule syntax: [match expressions] [action]
iif lo accept
ct state established,related accept
ct state invalid drop
ip saddr 192.168.1.0/24 tcp dport 22 accept
tcp dport { 80, 443 } accept
ip saddr @blocked_ips drop

# Complete config file
#!/usr/sbin/nft -f

flush ruleset

table inet firewall {
    set blocked_ips {
        type ipv4_addr
        elements = { 1.2.3.4, 5.6.7.8 }
    }

    set temp_blocks {
        type ipv4_addr
        flags timeout
    }

    chain input {
        type filter hook input priority 0; policy drop;

        iif lo accept
        ct state established,related accept
        ct state invalid drop
        ip saddr @blocked_ips drop
        ip saddr 192.168.1.0/24 tcp dport 22 accept
        tcp dport { 80, 443 } accept
        icmp type echo-request accept
        log prefix "dropped: "
        reject with icmp type port-unreachable
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
        iif eth1 oif eth0 accept
        iif eth0 oif eth1 ct state established,related accept
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }

    chain postrouting {
        type nat hook postrouting priority 100;
        oif eth0 masquerade
    }
}

# Verdict maps — one rule instead of many
tcp dport vmap { 22 : accept, 80 : accept, 443 : accept, 23 : drop }

# Sets with timeout — temporary blocks
nft add element inet firewall temp_blocks { 1.2.3.4 timeout 1h }

# Add/remove elements at runtime
nft add element inet firewall blocked_ips { 9.9.9.9 }
nft delete element inet firewall blocked_ips { 9.9.9.9 }

# Migrate from iptables
iptables-restore-translate -f /etc/iptables/rules.v4
```

---

### conntrack & tcpdump

```bash
# conntrack — connection tracking table
sudo conntrack -L                   # list all connections
sudo conntrack -L -p tcp            # filter by protocol
sudo conntrack -L --state ESTABLISHED
sudo conntrack -E                   # watch in real time
sudo conntrack -C                   # count
sudo conntrack -D -p tcp --src 1.2.3.4   # delete entry

# conntrack output format:
# tcp 6 431999 ESTABLISHED src=192.168.1.5 dst=1.2.3.4 sport=54321 dport=443
#                           src=1.2.3.4 dst=192.168.1.5 sport=443 dport=54321 [ASSURED]
# Two sets of src/dst = original direction and reply direction

# Conntrack table limits
sudo conntrack -C
cat /proc/sys/net/netfilter/nf_conntrack_max
echo 131072 | sudo tee /proc/sys/net/netfilter/nf_conntrack_max

# tcpdump
sudo tcpdump -i eth0 -n             # no hostname resolution
sudo tcpdump -i eth0 -nv            # verbose
sudo tcpdump -i any -n              # all interfaces
sudo tcpdump -i eth0 -w capture.pcap    # write to file
sudo tcpdump -r capture.pcap            # read file

# Filters
sudo tcpdump -i eth0 host 192.168.1.10
sudo tcpdump -i eth0 src 192.168.1.10
sudo tcpdump -i eth0 port 443
sudo tcpdump -i eth0 tcp
sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'   # SYN only
sudo tcpdump -i eth0 host 1.2.3.4 and port 80
sudo tcpdump -i eth0 not port 22

# Debugging workflow — port forward not working
sudo tcpdump -i eth0 port 8080          # traffic arriving?
cat /proc/sys/net/ipv4/ip_forward       # forwarding enabled?
sudo nft list ruleset | grep forward    # forward rule exists?
sudo conntrack -E | grep 8080           # DNAT translating?
sudo tcpdump -i eth1 host 192.168.1.10  # reaching internal server?
```

---

## Module 4 — Troubleshooting

### Disk Space

```bash
df -h                               # filesystem usage
df -i                               # inode usage
du -sh /*                           # top level usage
du -sh * | sort -rh | head -10      # largest directories

# Deleted files still using space
sudo lsof +L1                       # files with link count < 1
sudo truncate -s 0 /proc/PID/fd/N   # free space without restart

# Find large files
find / -type f -size +1G 2>/dev/null | sort
```

---

### Locked Files & Processes

```bash
sudo lsof /path/to/file             # who has file open
sudo lsof +D /var/log/              # who has directory open
sudo lsof -p 1234                   # all files a process has open
sudo lsof -i :80                    # who is using port 80
sudo lsof -i tcp:443
sudo fuser /path/to/file            # simpler — just PIDs
sudo fuser -k /path/to/file         # kill process holding file

# Process tools
ps aux --sort=-%cpu | head -10
ps aux --sort=-%mem | head -10
pgrep -a nginx                      # find by name with command
pkill nginx                         # kill by name
pstree -p                           # process tree with PIDs

# strace — system call tracer
sudo strace -p PID                  # attach to running process
sudo strace -p PID -e trace=openat,read,write
sudo strace command 2>&1 | grep "No such file"   # find missing files
```

---

### Memory & I/O

```bash
# Memory
free -h
cat /proc/meminfo | grep -E "MemAvailable|SwapFree"
sudo dmesg | grep -i "oom\|killed process"
sudo journalctl | grep -i "out of memory"

# I/O
sudo iostat -x 2                    # I/O stats every 2 seconds
# %util = device saturation, await = request latency
sudo iotop -o                       # processes doing I/O now
cat /proc/diskstats                 # raw stats

# Core dumps
ulimit -c unlimited                 # enable
cat /proc/sys/kernel/core_pattern   # where dumps go
sudo coredumpctl list
sudo coredumpctl debug PID          # open in gdb
```

---

## Quick Reference — Common One-liners

```bash
# System info from /proc
awk '/MemTotal/ {total=$2} /MemAvailable/ {avail=$2} END {printf "used: %.1f%%\n", (total-avail)/total*100}' /proc/meminfo
awk '/model name/ {print $0; exit}' /proc/cpuinfo
awk '{print int($1/86400)"d", int($1%86400/3600)"h", int($1%3600/60)"m"}' /proc/uptime
grep -c "^processor" /proc/cpuinfo

# Network
ss -tlnp                            # listening TCP ports with PIDs
sudo conntrack -L | awk '{print $4}' | sort | uniq -c | sort -rn
awk 'NR>2 {gsub(/:/, "", $1); print $1, $2}' /proc/net/dev

# Process one-liners
sudo lsof +L1 | awk 'NR>1 {count[$1]++} END {for (v in count) print count[v], v}' | sort -rn
ps aux | awk 'NR>1 {sum[$11] += $6} END {for (p in sum) print sum[p]/1024, p}' | sort -rn | head -10

# Log analysis
awk '{counts[$3]++} END {for (k in counts) print counts[k], k}' app.log | sort -rn
awk '/ERROR/ {count++} END {print count+0, "errors in", NR, "lines"}' app.log
```

---

*Generated from a learning session covering Modules 1-4. Modules 5-7 (Kernel Building, Containers & VMs, Dev Workflow) to be added.*
