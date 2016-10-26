# dedi.serv

```bash
wget -qO- https://github.com/peondusud/dedi.serv/raw/master/net.sh | bash -
```
Or

```bash
bash -c "$(wget -qO- https://github.com/peondusud/dedi.serv/raw/master/net.sh)"
```


Check open ports:
```bash
nmap -T4 -A -sC -sV -p1-65536 domain.org
```

Check HTTPS setup (cipher suite,...)
  ```
  https://www.ssllabs.com/ssltest/analyze.html?d=domain.org&hideResults=on&latest
  ```
