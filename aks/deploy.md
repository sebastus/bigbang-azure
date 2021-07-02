# Azure Deployment 

This is a fast (ish) way to deploy BigBang into Azure using AKS

## Pre-reqs

Due to the way BigBang is designed and the reliance on gitops and flux there are several pre-reqs that can not be automated or scripted

### 1. Local Tools

Local tools & environment required are:

- Azure CLI
- kubectl
- bicep
- gpg (`sudo apt-get install -y gpg`)
- sops
- Bash (Linux / WSL2 / MacOS)

Install scripts for all these can be obtained here https://github.com/benc-uk/tools-install

### 1. Accounts

- GitHub account
- [GitHub PAT](https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [Iron Bank Account](https://ironbank.dso.mil/)

### 2. Set Up Git Repo

1. Fork this repo on GitHub https://github.com/benc-uk/bigbang-azure
1. Clone your fork locally
1. Create branch called "azure" and push up to GitHub to track this branch
    ```bash
    git checkout -b azure
    git push -u origin azure
    ```

### 3. Create Keys and Configure Repo

In the interest of not duplicating instructions, follow the steps in the [main readme](../README.md) for the following sections:

> Note. The branch name is "azure", and it's VERY IMPORTANT not to set a passphrase on the key when gpg prompts you.

- Create GPG Encryption Key
- Add Pull Credentials
- Configure for GitOps

### 4. Deploy

1. Copy `secrets.sh.sample` to `secrets.sh` and edit to set the values
2. Copy `deploy-vars.sh.sample` to `deploy-vars.sh` and configure as you wish


Run the deployment script