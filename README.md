# quectel-scripts

Configuration scripts for Quectel modules (5G UE) on R2Lab / SophiaNode nodes.

## Install on a node

```bash
git clone <repo-url> quectel-scripts
cd quectel-scripts
sudo make install        # copies bin/* into /usr/local/bin
```

## Update

```bash
cd quectel-scripts
git pull
sudo make install
```

## Make targets

- `make install`   — install the scripts into /usr/local/bin
- `make uninstall` — remove them
- `make list`      — current version + list of scripts

The version is derived from git tags (`git describe`).
