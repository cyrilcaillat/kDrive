# kDrive
Dernières versions

# anacrontab

```bash
echo '1      15       kdrive-update     /home/cyril/git/kDrive/update-kdrive.sh >> /var/log/update-kdrive.log 2>&1' | sudo tee -a /etc/anacrontab
```