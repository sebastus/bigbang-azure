# Notes on getting BigBang to deploy

These are personal companion notes to the main [README.md](./README.md)

The dev/configmap.yaml has been altered from the defaults:

- Force jaeger to use version 1.23.0 images to fix containerd issue
- nodeSelector added to elasticsearch to use a specific node pool, see [aks/readme.me](./aks/readme.md)
- hostname changed

## 1. Git Repo

Clone repo https://repo1.dso.mil/platform-one/big-bang/customers/template

Remove origin remote and push to github

```
git remote remove origin
git remote add origin https://github.com/benc-uk/bigbang.git
git branch -M main
git push -u origin main
```

create branch called "azure" and push

```
git checkout -b azure
git push -u origin azure
```

## 2. Keys

Follow steps in "Create GPG Encryption Key"

**👁‍🗨 IMPORTANT! DO NOT SET A PASSPHRASE ON THE KEY**

## 3. Initial config

Follow steps in "Add Pull Credentials" and push changes to GitHub

Follow steps in "Configure for GitOps"

In dev/bigbang.yaml

- The git URL points to this repo https://github.com/benc-uk/bigbang.git
- Branch was set to "azure"

## 4. Deploy

Follow steps in "Deploy" as follows:

```bash
kubectl create namespace bigbang
```

```bash
gpg --export-secret-key --armor ${fp} | kubectl create secret generic sops-gpg -n bigbang --from-file=bigbangkey=/dev/stdin
```

> Note. this must run in the same terminal that step 2 was run in to that $fp variable is set

```bash
kubectl create secret generic private-git \
 --from-literal=username='__GITHUB_USER__' \
 --from-literal=password='__GITHUB_PAT__' \
 -n bigbang
```

> Note. The use of GitHub details here not repo1, Change `__GITHUB_USER__` and `__GITHUB_PAT__` to their real values

**👁‍🗨 NOTE! For flux deployment the steps in the readme are out of date!**

The following script should be used from the main bigbang repo:
https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/scripts/install_flux.sh

e.g.

```bash
./scripts/install_flux.sh \
  --registry-username '__IRON_BANK_USERNAME__' \
  --registry-password '__IRON_BANK_PAT__' \
  --registry-email bigbang@bigbang.dev
```

> Note. Change `__IRON_BANK_USERNAME__` and `__IRON_BANK_PAT__` to their real values

```bash
cd dev
kubectl apply -f bigbang.yaml
```

Carry out the rest of the checks in the "Deploy Big Bang" section
