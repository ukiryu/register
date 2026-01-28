# BusyBox Support in Ukiryu Register

## Philosophy

Not every CLI tool should be a Ruby wrapper. We prioritize:

1. **Tools where CLI is significantly better than Ruby libraries** - If Ruby handles it well, don't create a CLI wrapper
2. **Tools with meaningful implementation differences** - Only create interfaces when GNU and BusyBox versions differ significantly
3. **Tools commonly used in DevOps/automation** - Focus on high-frequency, high-impact tools
4. **Minimize technical debt** - Each interface doubles maintenance burden

## Supported Interfaces

These tools have separate GNU and BusyBox implementations. The framework auto-selects the correct implementation based on platform and availability.

| Interface | GNU Implementation | BusyBox Implementation | Justification |
|----------|-------------------|----------------------|----------------|
| **ping** | `ping_gnu` (Linux iputils) | `ping_bsd` (macOS/BSD) | Different implementations for different platforms |
| **gzip** | `gzip_gnu` (GNU gzip 1.12) | `gzip_busybox` (BusyBox 1.36.1) | Alpine uses BusyBox, different version detection |
| **bzip2** | `bzip2_gnu` (GNU bzip2 1.0.6) | `bzip2_busybox` (BusyBox 1.36.1) | Alpine uses BusyBox, different version detection |
| **tar** | `tar_gnu` (GNU tar 1.35) | `tar_busybox` (BusyBox) | Alpine compatibility, feature differences |
| **grep** | `grep_gnu` (GNU grep 3.12) | `grep_busybox` (BusyBox) | Alpine compatibility, regex differences |
| **sed** | `sed_gnu` (GNU sed 4.9) | `sed_busybox` (BusyBox) | Alpine compatibility, BusyBox missing `-i` |
| **find** | `find_gnu` (GNU find 4.9) | `find_busybox` (BusyBox) | Alpine compatibility, expression differences |
| **wget** | `wget_gnu` (GNU wget 1.24) | `wget_busybox` (BusyBox) | Alpine compatibility, BusyBox very limited |
| **awk** | `awk_gnu` (GNU awk gawk 5.3) | `awk_busybox` (BusyBox) | Alpine compatibility, feature differences |

**Total: 9 interfaces, 18 implementations**

## Monolithic Tools (Single Implementation)

These tools are in the register but don't distinguish between GNU and BusyBox because:

1. **No BusyBox equivalent exists** - The tool is not part of BusyBox
2. **BusyBox equivalent is nearly identical** - No meaningful difference
3. **Tool is platform-specific** - Only exists on certain platforms

| Tool | Reason |
|------|--------|
| `curl` | No BusyBox equivalent (different tool) |
| `ssh`, `scp` | OpenSSH tools, not in BusyBox |
| `git` | Not in BusyBox, separate implementation |
| `ansible` | Not in BusyBox, Python-based |
| `make` | GNU make, BusyBox make is very different |
| `vim` | Not in BusyBox (vi is different) |
| `ffmpeg` | Not in BusyBox, specialized media tool |
| `ImageMagick` | Not in BusyBox, specialized image tool |
| `ghostscript` | Not in BusyBox, specialized PDF tool |
| `jq` | JSON processor, not in BusyBox |
| `yq` | YAML processor, not in BusyBox |
| `fzf` | Fuzzy finder, not in BusyBox |
| `fd` | Find alternative, not in BusyBox |
| `bat` | Cat alternative, not in BusyBox |
| `rg` (ripgrep) | Grep alternative, not in BusyBox |
| `exiftool` | Metadata tool, not in BusyBox |
| `pandoc` | Document converter, not in BusyBox |
| `inkscape` | SVG editor, not in BusyBox |
| `jpegoptim`, `optipng` | Image optimizers, not in BusyBox |
| `pdf2ps`, `pdftk` | PDF tools, not in BusyBox |
| `openssl` | Cryptography toolkit, not in BusyBox |
| `sort` | Minimal differences, monolithic OK |
| `head`, `tail` | Minimal differences, monolithic OK |
| `wc` | Minimal differences, monolithic OK |
| `cut` | Minimal differences, monolithic OK |
| `diff`, `patch` | Minimal differences, monolithic OK |
| `xargs` | Minimal differences, monolithic OK |

## Use Ruby Built-Ins Instead

These BusyBox applets should **NOT** be added to the register. Use Ruby's built-in functionality instead.

### File Operations (FileUtils, Dir, File)

| BusyBox Applet | Ruby Alternative | Why |
|----------------|------------------|-----|
| `rm` | `FileUtils.rm`, `FileUtils.rm_rf` | Ruby handles deletion perfectly |
| `rmdir` | `Dir.rmdir`, `FileUtils.rmdir` | Ruby handles directory removal |
| `mkdir` | `Dir.mkdir`, `FileUtils.mkdir_p` | Ruby handles directory creation |
| `pwd` | `Dir.pwd` | Ruby handles working directory |
| `cp` | `FileUtils.cp`, `FileUtils.cp_r` | Ruby handles copying |
| `mv` | `FileUtils.mv` | Ruby handles moving |
| `ln` | `FileUtils.ln`, `FileUtils.symlink` | Ruby handles links |
| `ls` | `Dir.entries`, `Dir.glob` | Ruby handles directory listing |
| `touch` | `FileUtils.touch` | Ruby handles timestamp updates |
| `chmod` | `File.chmod`, `FileUtils.chmod` | Ruby handles permissions |
| `chown` | `FileUtils.chown` | Ruby handles ownership |
| `cat` | `File.read`, `File.write` | Ruby handles file reading/writing |
| `test` | `File.exist?`, `File.directory?`, `File.file?`, etc. | Ruby handles file tests |
| `stat` | `File.stat`, `File.lstat` | Ruby handles file status |
| `basename` | `File.basename` | Ruby handles basename |
| `dirname` | `File.dirname` | Ruby handles dirname |
| `realpath` | `File.realpath` | Ruby handles realpath |
| `readlink` | `File.readlink` | Ruby handles symlinks |
| `split` | `String#split` | Ruby handles splitting |

### Text Operations (String, Enumerable)

| BusyBox Applet | Ruby Alternative | Why |
|----------------|------------------|-----|
| `echo` | `puts`, `print` | Ruby handles output |
| `printf` | `String#%`, `format`, `sprintf` | Ruby handles formatted output |
| `tac` | `array.reverse` or `File.readlines.reverse` | Ruby handles reversal |
| `uniq` | `Array#uniq` | Ruby handles uniqueness |
| `wc` | `String#lines.count`, `String#chars.count`, `String#bytes.count` | Ruby handles counting |
| `tr` | `String#tr` | Ruby handles translation |
| `head` | `File.open().first(n)` or `Array#first` | Ruby handles reading start |
| `tail` | `File.open().last(n)` or `Array#last` | Ruby handles reading end |
| `cut` | `String#split` | Ruby handles column extraction |
| `expand` | String methods | Ruby handles tab expansion |
| `fold` | String methods | Ruby handles line wrapping |
| `od` | `String#unpack` | Ruby handles octal dump |
| `sort` | `Array#sort` | Ruby handles sorting (for in-memory data) |
| `comm` | Array operations | Ruby handles common lines |
| `paste` | Array#zip | Ruby handles column joining |
| `join` | `Array#join` | Ruby handles joining |

### Date/Time Operations

| BusyBox Applet | Ruby Alternative | Why |
|----------------|------------------|-----|
| `date` | `Time`, `Date`, `DateTime` | Ruby has excellent date/time support |
| `sleep` | `Kernel.sleep` | Ruby handles sleeping |
| `usleep` | `Kernel.sleep` with fractions | Ruby handles microsleep |

### Process Operations

| BusyBox Applet | Ruby Alternative | Why |
|----------------|------------------|-----|
| `kill` | `Process.kill` | Ruby handles signal sending |
| `killall` | `Process.kill` with iteration | Ruby handles killing all |
| `ps` | `Process` class, `sys-proctree` gem | Libraries handle process listing better |
| `pidof` | `Process.pid` or system calls | Ruby handles PID lookup |
| `nice` | `Process.setpriority` | Ruby handles priority |
| `renice` | `Process.setpriority` | Ruby handles priority change |
| `nohup` | Process spawn options | Ruby handles nohup |

### System Information

| BusyBox Applet | Ruby Alternative | Why |
|----------------|------------------|-----|
| `uname` | `RbConfig::CONFIG`, `Gem.platform` | Ruby handles system info |
| `hostname` | `Socket.gethostname` | Ruby handles hostname |
| `id` | `Process.uid`, `Process.gid` | Ruby handles user/group ID |
| `env` | `ENV` | Ruby handles environment |
| `who` | `Process` classes | Libraries handle user info |
| `whoami` | `Process.euid` | Ruby handles current user |
| `logname` | `ENV['USER']` | Ruby handles login name |
| `uptime` | System commands or libraries | Ruby can call but rarely needed |
| `df` | System commands or libraries | Ruby can call but rarely needed |
| `du` | System commands or libraries | Ruby can call but rarely needed |
| `free` | System commands or libraries | Ruby can call but rarely needed |

### Network Operations

| BusyBox Applet | Ruby Alternative | Why |
|----------------|------------------|-----|
| `ifconfig` | `Socket` interface, system commands | Use cloud APIs instead |
| `route` | System commands, cloud APIs | Use cloud APIs instead |
| `netstat` | `Socket` interface, libraries | Use cloud APIs instead |
| `arp` | System commands | Use cloud APIs instead |
| `ping` | `net/ping` library | We support ping as interface |

### Special Values

| BusyBox Applet | Ruby Alternative | Why |
|----------------|------------------|-----|
| `true` | `true` | Ruby has true literal |
| `false` | `false` | Ruby has false literal |
| `yes` | `loop { puts "y" }` | Ruby handles repetition |

## Not Supported (With Reasons)

These BusyBox applets are explicitly **not supported** in the register.

### Interactive Tools (Not Automation-Friendly)

Interactive tools are designed for human use, not automation. They don't fit the CLI automation pattern.

| Tool | Reason |
|------|--------|
| `vi`, `ed` | Interactive editors - use Ruby file operations |
| `less`, `more` | Interactive pagers - use Ruby for data processing |
| `top`, `htop` | Interactive monitors - use libraries instead |
| `watch` | Interactive watcher - write Ruby loops instead |
| `vlock` | Interactive screen lock - not applicable |
| `reset` | Terminal reset - not automation-friendly |

### Dangerous System Operations

These tools perform dangerous operations that should not be done via Ruby automation.

| Tool | Reason |
|------|--------|
| `fdisk` | Disk partitioning - dangerous, use cloud APIs |
| `mkfs`, `mkfs.vfat`, `mkfs.minix` | Filesystem creation - dangerous |
| `mkswap` | Swap creation - dangerous |
| `mount`, `umount` | Mount operations - use Chef/puppet/ansible instead |
| `swapon`, `swapoff` | Swap management - system administration |
| `halt`, `reboot`, `poweroff`, `shutdown` | System control - use cloud APIs |
| `init` | Init system - not for automation |
| `killall5` | Dangerous process killing |

### Firewall/Security

| Tool | Reason |
|------|--------|
| `iptables` | Firewall rules - use cloud security groups |
| `arping` | ARP manipulation - low-level network |
| `inetd` | Internet daemon - use dedicated services |

### Hardware/Device Management

| Tool | Reason |
|------|--------|
| `hdparm` | Disk parameters - low-level hardware |
| `setfont`, `loadfont` | Console fonts - system-specific |
| `loadkmap`, `kbd_mode` | Keyboard settings - system-specific |
| `setkeycodes`, `setlogcons` | Console settings - system-specific |
| `deallocvt` | Virtual terminal management - system-specific |
| `chvt`, `openvt` | Terminal switching - system-specific |
| `flash_lock`, `flash_unlock` | Flash memory - embedded systems |
| `fdformat` | Floppy formatting - obsolete |

### Server Daemons

These are server processes, not CLI automation tools.

| Tool | Reason |
|------|--------|
| `httpd` | HTTP server - use dedicated web servers |
| `ftpd`, `tftpd` | FTP/TFTP servers - use dedicated servers |
| `telnetd` | Telnet server - insecure, use SSH |
| `inetd` | Internet superserver - use dedicated init |
| `crond` | Cron daemon - use system cron |
| `syslogd`, `klogd` | Logging daemons - use system logging |

### Boot/Initialization

| Tool | Reason |
|------|--------|
| `linuxrc`, `switch_root` | Boot scripts - embedded systems |
| `init` | Init system - not for automation |

### Specialized/Obsolete

| Tool | Reason |
|------|--------|
| `man` | Documentation - use web/docs instead |
| `makedevs` | Device creation - system administration |
| `mkfifo` | Named pipes - rare, use Ruby |
| `mknod` | Device nodes - system administration |
| `getty` | Login management - system administration |
| `login` | Login process - use SSH/keys instead |
| `su` | User switching | Use privilege separation in architecture |
| `passwd` | Password management | Use SSH keys, cloud IAM |
| `cryptpw` | Password hashing | Use bcrypt/argon2 libraries |
| `chpasswd` | Password updates | System administration |

### Scripting/Build Tools

| Tool | Reason |
|------|--------|
| `sh`, `ash`, `hush` | Shells - Use Ruby directly |
| `script`, `scriptreplay` | Terminal recording - niche use |
| `make` | Build tool - Use Rake instead |

### Package Managers

| Tool | Reason |
|------|--------|
| `dpkg` | Debian packages - Use system package manager |
| `rpm`, `rpm2cpio` | RPM packages - Use system package manager |

### Obscure/Rarely Used

| Tool | Reason |
|------|--------|
| `beep` | Sound - not for servers |
| `clear` | Screen clear - cosmetic |
| `cksum` | Checksum - use Ruby digest libraries |
| `cmp` | Compare - use Ruby |
| `comm` | Common lines - use Ruby |
| `dc` | Calculator - use Ruby |
| `dd` | Disk copy - use Ruby or specialized tools |
| `devmem` | Device memory - low-level |
| `dmesg` | Kernel messages - system administration |
| `dnsd`, `dnsdomainname` | DNS - use dedicated DNS |
| `dhcprelay` | DHCP - use dedicated DHCP |
| `du`, `dumpkmap`, `dumpleases` | Niche system tools |
| `eject` | Media eject - hardware control |
| `envdir`, `envuidgid`, `chpst` | Runit tools - use dedicated init |
| `expand` | Text processing - use Ruby |
| `expr` | Expressions - use Ruby |
| `fakeidentd` | Ident daemon - niche |
| `fbset`, `fbsplash` | Framebuffer - graphical systems |
| `fdflush`, `fdformat` | Floppy disk - obsolete |
| `fold` | Text wrapping - use Ruby |
| `freeramdisk` | Memory management - system administration |
| `fsck`, `fsck.minix` | Filesystem check - system administration |
| `ftpd`, `ftpget`, `ftpput` | FTP - use S3/SCP instead |
| `fuser` | Process/file user - system administration |
| `getopt` | Option parsing - use Ruby OptionParser |
| `hexdump`, `hd` | Hex dump - use Ruby |
| `hostid` | Host ID - system identification |
| `hwclock` | Hardware clock - system time |
| `ifdown`, `ifenslave`, `ifplugd`, `ifup` | Network configuration - use network manager |
| `inotifyd` | File monitoring - use Ruby libraries |
| `insmod`, `lsmod`, `rmmod`, `modprobe` | Kernel modules - system administration |
| `ionice` | I/O scheduling - system administration |
| `ip`, `ipaddr`, `ipcalc`, `ipcrm`, `ipcs`, `iplink`, `iproute`, `iprule`, `iptunnel` | Advanced IP - use system/network tools |
| `klogd` | Kernel logging - system administration |
| `last` | Login history - system accounting |
| `length` | String length - use Ruby |
| `lzdma`, `lzop`, `lzmacat`, `lzopcat`, `unlzma`, `unlzop` | Compression - less common |
| `logger` | Syslog - use Ruby syslog libraries |
| `lpd`, `lpq`, `lpr` | Printing - use dedicated print servers |
| `losetup` | Loop devices - system administration |
| `lsattr` | File attributes - system administration |
| `mdev` | Device management - embedded systems |
| `mesg` | Terminal control - obsolete |
| `microcom` | Serial port - hardware |
| `mkdosfs` | FAT filesystem - use system tools |
| `mknod` | Device nodes - system administration |
| `mkpasswd` | Password generation - use Ruby libraries |
| `mktemp` | Temp files - use Ruby Tempfile |
| `more` | Pager - use Ruby for processing |
| `mountpoint` | Mount check - system administration |
| `mt` | Magnetic tape - obsolete |
| `nameif` | Network naming - system administration |
| `nc` | Netcat - use Ruby sockets |
| `nslookup` | DNS lookup - use Ruby Resolv |
| `od` | Octal dump - use Ruby |
| `patch` | Patch application - Already in register |
| `pipe_progress` | Progress bar - UI element |
| `pivot_root` | Root change - embedded boot |
| `pkill`, `pgrep` | Process tools - use Ruby/Process |
| `popmaildir` | Mail - use mail libraries |
| `printenv` | Environment - use ENV/puts |
| `raidautorun` | RAID - system administration |
| `rdate` | Remote time - use NTP |
| `rdev` | Device info - obsolete |
| `readprofile` | Kernel profiling - system development |
| `reformime` | Mail reformatter - use mail libraries |
| `reset` | Terminal reset - interactive |
| `resize` | Terminal resize - automatic |
| `runsv`, `runsvdir` | Runit tools - use dedicated init |
| `run-parts` | Script runner - simple loop |
| `rx` | Receive fax - obsolete |
| `sendmail` | Mail transfer - use mail libraries |
| `setarch`, `setconsole` | System settings - system administration |
| `setsid` | Session ID - use Ruby Process |
| `setuidgid` | User/group - use Ruby Process |
| `sha1sum`, `sha256sum`, `sha512sum` | Checksums - use Ruby Digest |
| `showkey` | Keyboard debugging - hardware |
| `slattach` | Serial line - hardware |
| `softlimit` | Resource limits - use Ruby Process |
| `strings` | String extraction - specialized use |
| `stty` | Terminal settings - interactive |
| `sv`, `svlogd` | Runit tools - use dedicated init |
| `swapoff`, `swapon` | Swap management - system administration |
| `switch_root` | Root change - embedded boot |
| `sync` | Sync buffers - use Ruby IO.flush |
| `sysctl` | System parameters - use sysctl gems or cloud APIs |
| `tac` | Reverse cat - use Ruby reverse |
| `taskset` | CPU affinity - system administration |
| `tcpsvd` | TCP server daemon | use dedicated servers |
| `tee` | Tee output - use Ruby pipes |
| `telnet`, `telnetd` | Telnet - insecure, use SSH |
| `test` | File test - use Ruby File methods |
| `tftp`, `tftpd` | TFTP - use S3/SCP instead |
| `time` | Timing - use Ruby Benchmark |
| `timeout` | Timeout - use Ruby Timeout |
| `touch` | Touch file - use Ruby FileUtils.touch |
| `traceroute` | Network trace - Already in register or use cloud tools |
| `true` | True value - use Ruby true |
| `tty` | Terminal name - use Ruby IO.tty? |
| `ttysize` | Terminal size | use ruby gems |
| `udhcpc`, `udhcpd`, `udpsvd` | DHCP | use dedicated DHCP or cloud networking |
| `uncompress` | Decompress | use other tools |
| `unexpand` | Tab conversion | text processing, use Ruby |
| `uptime` | Uptime | system monitoring, use cloud metrics |
| `usleep` | Microsleep | use Ruby sleep with fractions |
| `uudecode`, `uuencode` | Encoding | specialized use |
| `vconfig` | VLAN | network configuration, use cloud networking |
| `volname` | Volume name | system administration |
| `watch` | Watch command | write Ruby loop |
| `watchdog` | Watchdog timer | hardware/embedded |
| `which` | Which | use Ruby Which executable or system command |
| `yes` | Yes output | use Ruby loop |
| `zcat` | Zip cat | use Ruby |
| `zcip` | ZeroConf IP | use cloud networking |

## Adding New BusyBox Interfaces

When considering adding a new BusyBox interface, evaluate:

1. **Is it already handled well by Ruby?** If yes, don't add it.
2. **Does it have significant GNU vs BusyBox differences?** If no, monolithic profile may suffice.
3. **Is it commonly used in DevOps/automation?** If no, reconsider.
4. **Will the maintenance burden justify the benefit?** Each interface doubles maintenance.

## Maintenance Guidelines

- **Keep interfaces minimal** - Only create interfaces when necessary
- **Document decisions** - Every interface should have clear justification
- **Test both implementations** - Ensure GNU and BusyBox versions work correctly
- **Version detection** - Use appropriate version detection patterns for each
- **Search paths** - Include BusyBox paths (`/bin/`) for Alpine Linux compatibility

## See Also

- [Tool Schema Documentation](https://github.com/ukiryu/schema)
- [Register README](README.adoc)
- [Interface Example](interfaces/tar/1.0.yaml)
