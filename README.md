# dedi.serv

```bash
wget -qO- https://github.com/peondusud/dedi.serv/raw/master/net.sh | bash -x -
```

```bash
wget -qO- https://github.com/peondusud/dedi.serv/raw/master/debian.sh | bash -x -
```

```bash
wget --no-check-certificate -qO- https://github.com/peondusud/dedi.serv/raw/master/debian.sh ; bash -x -
```

Check open ports:
```bash
nmap -T4 -A -sC -sV -p1-65536 domain.org
```

Check HTTPS setup (cipher suite,...)
  ```
  https://www.ssllabs.com/ssltest/analyze.html?d=domain.org&hideResults=on&latest
  ```
