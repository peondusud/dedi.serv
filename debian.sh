#!/bin/bash

USERNAME="peon"
SSH_PORT=22222

echo "Add new user: ${USERNAME}"
useradd -ms /bin/zsh "${USERNAME}"
passwd "${USERNAME}"

apt-get update
apt-get dist-upgrade

apt-get install -y htop curl unzip git subversion sudo nano vim zsh mlocate
apt-get remove -y bind9

updatedb

echo "Add ${USERNAME} to sudoers"
echo "${USERNAME}    ALL=(ALL:ALL) ALL" >> /etc/sudoers

echo "setting SSH config"
#ssh server conf
sed -i "s|\(Port\).*$|\1 ${SSH_PORT}|" /etc/ssh/sshd_config
sed -i "s|\(PermitRootLogin\).*$|\1 no|" /etc/ssh/sshd_config
sed -i "s|\(X11Forwarding\).*$|\1 no|" /etc/ssh/sshd_config
echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config


echo "on your desktop, to use certificat:
      ssh-copy-id -i ~/.ssh/id_rsa.pub root@domain.org"
      
echo "Once done press [ENTER] to restart ssh service"
read -n 1 -s

systemctl restart ssh.service

echo "
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
# Enable TCP/IP SYN cookies
net.ipv4.tcp_syncookies = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1

# protect against tcp time-wait assassination hazards drop RST packets for sockets in the time-wait state
net.ipv4.tcp_rfc1337 = 1

# Reverse path filtering mechanism source validation of the packet's recieved from all the interfaces on the machine protects from attackers that are using ip spoofing methods
net.ipv4.conf.all.rp_filter = 1
net.ipv6.conf.all.rp_filter = 1

## send redirects (not a router, disable it)
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.send_redirects = 0

# Do not accept ICMP redirects (prevent MITM attacks)
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Do not accept IP source route packets (we are not a router)
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Disable IPv6 autoconf
net.ipv6.conf.all.autoconf = 0
net.ipv6.conf.default.autoconf = 0
net.ipv6.conf.eth0.autoconf = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

#Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
" >  /etc/sysctl.d/local.conf

# reload sysctl
echo "reload sysctl config"
sysctl --system


# nftables
apt-get install -y nftables ulogd2 ulogd2-sqlite3 ulogd2-pcap ulogd2-json
#nft flush table filter

mkdir /etc/nftables
echo "#! @sbindir@nft -f

#NF_IP_PRI_CONNTRACK_DEFRAG (-400): priority of defragmentation
#NF_IP_PRI_RAW (-300): traditional priority of the raw table placed before connection tracking operation
#NF_IP_PRI_SELINUX_FIRST (-225): SELinux operations
#NF_IP_PRI_CONNTRACK (-200): Connection tracking operations
#NF_IP_PRI_MANGLE (-150): mangle operation
#NF_IP_PRI_NAT_DST (-100): destination NAT
#NF_IP_PRI_FILTER (0): filtering operation, the filter table
#NF_IP_PRI_SECURITY (50): Place of security table where secmark can be set for example
#NF_IP_PRI_NAT_SRC (100): source NAT
#NF_IP_PRI_SELINUX_LAST (225): SELinux at packet exit
#NF_IP_PRI_CONNTRACK_HELPER (300): connection tracking at exit 

define ext_if    = eth0

# symbolic anonymous set definition
define ssh_port = { ${SSH_PORT} }
define tcp_ports = { ssh, http, https}

# # https://docs.ovh.com/pages/releaseview.action?pageId=9928706
define ovh_icmp_check = {
                         ping.ovh.net,
                         a2.ovh.net,
                         proxy.p19.ovh.net,
                         proxy.rbx.ovh.net,
                         proxy.sbg.ovh.net,
                         proxy.bhs.ovh.net,
                         proxy.ovh.net,
                         rtm-collector.ovh.net,
                         151.80.231.244,
                         151.80.231.245,
                         151.80.231.246,
                         92.222.184.0/24,
                         92.222.185.0/24,
                         92.222.186.0/24,
                         167.114.37.0/24
                        }
" > /etc/nftables/fw.ruleset

echo ' 
table filter {
        set blackhole {
                type ipv4_addr
        }
        chain input {
                 type filter hook input priority 0;
                 ct state {established, related} accept
                 ct state invalid drop
                 iif lo accept
                 ip saddr $ovh_icmp_check icmp type { echo-request} limit rate 20/minute burst 25 packets counter packets 0 bytes 0 accept
                 tcp dport $ssh_port ct state new tcp flags & (syn | ack) == syn log prefix "input/ssh/accept: " counter  packets 0 bytes 0 accept
                 iif $ext_if tcp dport $tcp_ports counter accept
                 ip saddr @blackhole drop
                 counter log drop
        }
        chain forward {
                 type filter hook forward priority 0;
        }
        chain output{
                 type filter hook output priority 0;
                 ct state {established, related} accept
                 oif lo accept
                 ct state new counter accept
        }
}

# Use ip as fail2ban doesnt support ipv6 yet
table ip fail2ban {
        chain input {
                # Assign a high priority to reject as fast as possible and avoid more complex rule evaluation
                type filter hook input priority 100;
        }
}

table mangle {
        chain output            { type route hook output priority -150; }
}

table nat {
        chain prerouting        { type nat hook prerouting priority -150; }
        chain postrouting       { type nat hook postrouting priority -150; }
}

table bridge filter {
        chain input             { type filter hook input priority -200; }
        chain forward           { type filter hook forward priority -200; }
        chain output            { type filter hook output priority 200; }
}
' >> /etc/nftables/fw.ruleset

# load ruleset from file
nft -f /etc/nftables/fw.ruleset

# display full rules
nft list ruleset

## check is xt_LOG module exists
grep xt_LOG /lib/modules/$(uname -r)/modules.dep
## check is nfnetlink_log module exists
grep nfnetlink_log /lib/modules/$(uname -r)/modules.dep

modprobe xt_LOG nfnetlink_log
# xt_LOG is aliased to ipt_LOG and ip6t_LOG

## check netfilter log config
cat /proc/net/netfilter/nf_log  
## 2=IPv4, 4=Novell IPX, 10=IPv6, ...
#define AF_UNSPEC	  0
#define AF_UNIX		  1	/* Unix domain sockets 		*/
#define AF_INET		  2	/* Internet IP Protocol 	*/
#define AF_AX25		  3	/* Amateur Radio AX.25 		*/
#define AF_IPX		  4	/* Novell IPX 			*/
#define AF_APPLETALK  5	/* Appletalk DDP 		*/
#define AF_NETROM	  6	/* Amateur radio NetROM 	*/
#define AF_BRIDGE     7	/* Multiprotocol bridge 	*/
#define AF_AAL5		  8	/* Reserved for Werner's ATM 	*/
#define AF_X25		  9	/* Reserved for X.25 project 	*/
#define AF_INET6     10	/* IP version 6			*/
#define AF_MAX       12	/* For now.. */

# use ipt_LOG for IPv4
#echo "ipt_LOG" > /proc/sys/net/netfilter/nf_log/2

echo "nfnetlink_log" > /proc/sys/net/netfilter/nf_log/2
#echo "255" > /proc/sys/net/netfilter/nf_conntrack_log_invalid

# Ulogd setup
# use syslog
#sed -i "s|^#\(.*log3.*SYSLOG\)|\1|" /etc/ulogd.conf






#fail2ban
# based on https://wiki.meurisse.org/wiki/Fail2Ban
wget -O- http://neuro.debian.net/lists/jessie.de-m.libre > /etc/apt/sources.list.d/neurodebian.sources.list
apt-key adv --recv-keys --keyserver hkp://pgp.mit.edu:80 0xA5D32F012649A5A9
apt-get update
apt-get install --no-install-recommends --no-install-suggests -y fail2ban python-pyinotify rsyslog whois

mkdir /etc/nftables
echo "[Init]
# Definition of the table used
nftables_family = ip
nftables_table  = fail2ban

# Drop packets 
blocktype       = drop

# Remove nftables prefix. Set names are limited to 15 char so we want them all
nftables_set_prefix =
" > /etc/fail2ban/action.d/nftables-common.local

echo "[DEFAULT]
# Destination email for action that send you an email
destemail = root@localhost

# Sender email. Warning: not all actions take this into account. Make sure to test if you rely on this
sender    = root@localhost

# Default action. Will block user
#action    = %(action_)s
# Default action. Will block user and send you an email with whois content and log lines.
action    = %(action_mwl)s

# configure nftables
banaction = nftables-multiport
chain     = input
" > /etc/fail2ban/jail.local


echo "# Jail for more extended banning of persistent abusers
# !!! WARNINGS !!! 
# 1. Make sure that your loglevel specified in fail2ban.conf/.local
#    is not at DEBUG level -- which might then cause fail2ban to fall into
#    an infinite loop constantly feeding itself with non-informative lines
# 2. If you increase bantime, you must increase value of dbpurgeage
#    to maintain entries for failed logins for sufficient amount of time.
#    The default is defined in fail2ban.conf and you can override it in fail2ban.local
[recidive]
enabled   = true
logpath   = /var/log/fail2ban.log
banaction = nftables-allports
bantime   = 86400 ; 1 day
findtime  = 86400 ; 1 day 
maxretry  = 3 
protocol  = 0-255" > /etc/fail2ban/jail.d/recidive.conf

sed -i "s|\(port *=\) ssh|\1 ${SSH_PORT}|" /etc/fail2ban/jail.conf
#change sendmail to mail in jail.conf
#mta = sendmail

# docker
apt-get install -y apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo debian-jessie main" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-engine
sudo groupadd docker
gpasswd -a ${USERNAME} docker
service docker restart
docker pull debian:jessie
docker pull alpine:latest

# docker compose
curl -L https://github.com/docker/compose/releases/download/1.7.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose



# install http2 nginx version
apt install -y nginx-extras/jessie-backports

cd /tmp
git clone https://github.com/peondusud/nginx.SSL.offloader.git
cd nginx.SSL.offloader
bash -x conf.sh



