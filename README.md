# backup-util
utility scripts to compress a tarball from a target dir to be backed up to b2 using rclone
features include 
- flag `-l` / `--lightweight` to ignore node modules and venv packages, since that won't be portable accross machines& introduces compression overhead
- sources target paths to backup from a config file
- use rclone for b2 backup which makes it trivial to switch storage vendor.
- flag `-n` to toggle append backup artifacts with timestamp. 

## pre requisites
- rclone
- b2 account
- sudo privillage to allow compressing ALL files with tar

## installation
- create new config files from sample rclone, sample conf
- run `sudo crontab -e` and add the following entry (sample schedule, daily at 2AM)
```
0 2 * * * /bin/bash /home/ken/dev/backups/main.sh
```
- tarball and logs after run will be available in the `./artifacts` dir.


## future improvements
- [ ] handle workflow to keep only n back ups in artifacts & remove outdated ones.