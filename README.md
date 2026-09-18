# quectel-scripts

Configuration scripts for Quectel modules (5G UE) on R2Lab / SophiaNode nodes.

## Install on a node as root

```bash
git clone https://github.com/turletti/quectel-scripts.git /opt/quectel-scripts
cd quectel-scripts
make install        # copies bin/* into /usr/local/bin
```

## Update

```bash
cd /opt/quectel-scripts
git pull
make install
```

## Make targets

- `make install`   — install the scripts into /usr/local/bin
- `make uninstall` — remove them
- `make list`      — current version + list of scripts

The version is derived from git tags (`git describe`).
