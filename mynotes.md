# Notes on getting BigBang to deploy

## 1. Git Repo
Clone repo https://repo1.dso.mil/platform-one/big-bang/customers/template

Remove origin remote and push to github
```
git remote remove origin
git remote add origin https://github.com/benc-uk/bigbang.git
git branch -M main
git push -u origin main
```

create branch and push
```
git new azure
git push -u origin azure
```

## 2. Keys

Followed steps in "Create GPG Encryption Key"