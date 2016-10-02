#!/bin/bash

USERNAME="peon"
SSH_PORT=22222


install_req () {
      apt-get update
      apt-get dist-upgrade

      apt-get install -y htop curl unzip git subversion nano vim zsh 
      apt-get remove -y bind9
}


new_user_config () {
      sudo apt-get install -y sudo
      if (( $(id -u user > /dev/null 2>&1; echo $?) == 0 )); then
            echo "Add new user: ${USERNAME}"
            useradd -ms /bin/zsh "${USERNAME}"
            passwd "${USERNAME}"
      fi
      echo "Add ${USERNAME} to sudoers"
      echo "${USERNAME}    ALL=(ALL:ALL) ALL" >> /etc/sudoers
}


ssh_config () {

      echo "setting SSH config"
      #ssh server conf
      sed -i "s|\(Port\).*$|\1 ${SSH_PORT}|" /etc/ssh/sshd_config
      sed -i "s|\(PermitRootLogin\).*$|\1 no|" /etc/ssh/sshd_config
      sed -i "s|\(X11Forwarding\).*$|\1 no|" /etc/ssh/sshd_config
      echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config
      echo "AddressFamily inet # IPv4 only" >> /etc/ssh/sshd_config

      echo "On your desktop, to use certificat:"
      echo "ssh-copy-id -i ~/.ssh/id_rsa.pub root@domain.org"

      echo "Once done press [ENTER] to restart ssh service"
      read -n 1 -s
      systemctl restart ssh.service
}


sysctl_config () {
      wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/sysctl.d/local.conf -O /etc/sysctl.d/local.conf
      #mv sysctl.d/local.conf  /etc/sysctl.d/local.conf

      # reload sysctl
      echo "reload sysctl config"
      sysctl --system
}


nftables_config () {
      echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
      apt-get update
      apt-get install -y nftables ulogd2 ulogd2-sqlite3 ulogd2-pcap ulogd2-json
      #nft flush table filter

      mkdir -p  /etc/nftables
      wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/nftables/fw.ruleset -O /etc/nftables/fw.ruleset
      #mv nftables/fw.ruleset /etc/nftables/fw.ruleset

      # load ruleset from file
      nft -f /etc/nftables/fw.ruleset

      # display full rules
      nft list ruleset

      wget https://raw.githubusercontent.com/peondusud/dedi.serv/master/fail2ban/action.d/nftables-common.local -O /etc/fail2ban/action.d/nftables-common.local
      #mv fail2ban/action.d/nftables-common.local /etc/fail2ban/action.d/nftables-common.local

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
}

fail2ban_config () {
      # based on https://wiki.meurisse.org/wiki/Fail2Ban
      wget -O- http://neuro.debian.net/lists/jessie.de-m.libre > /etc/apt/sources.list.d/neurodebian.sources.list
      apt-key adv --recv-keys --keyserver hkp://pgp.mit.edu:80 0xA5D32F012649A5A9
      apt-get update
      apt-get install --no-install-recommends --no-install-suggests -y fail2ban python-pyinotify rsyslog whois

      wget https://github.com/peondusud/dedi.serv/blob/master/fail2ban/jail.local -O /etc/fail2ban/jail.local
      #mv fail2ban/jail.local /etc/fail2ban/jail.local

      wget https://github.com/peondusud/dedi.serv/blob/master/fail2ban/jail.d/recidive.conf -O /etc/fail2ban/jail.d/recidive.conf
      #mv fail2ban/jail.d/recidive.conf /etc/fail2ban/jail.d/recidive.conf

      sed -i "s|\(port *=\) ssh|\1 ${SSH_PORT}|" /etc/fail2ban/jail.conf
}

docker_config () {
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
}


nginx_config () {
      # install http2 nginx version
      apt install -y nginx-extras/jessie-backports

      cd /tmp
      git clone https://github.com/peondusud/nginx.SSL.offloader.git
      cd nginx.SSL.offloader
      bash -x conf.sh
}


install_basics () {
      install_req
      new_user_config
      ssh_config
      sysctl_config
      nftables_config
      fail2ban_config
}

install_req
new_user_config
ssh_config
sysctl_config
nftables_config
fail2ban_config
#docker_config
#nginx_config
