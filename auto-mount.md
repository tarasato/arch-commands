# Find uuid of drive
```bash
lsblk -f
```

# Create mount point
```bash
sudo mkdir -p /mnt/SN750-1TB
```

# Unmount
```bash
sudo umount /run/media/tarasato/SN750-1TB/
```

# Add to fstab
```bash
echo 'UUID=83086a05-714a-4120-833c-923695c69491  /mnt/SN750-1TB  ext4  defaults,noatime,nofail  0  2' | sudo tee -a /etc/fstab
```

# Testing
```bash
sudo systemctl daemon-reload
sudo mount -a
findmnt /mnt/SN750-1TB
```

# Add permission for writing
```bash
sudo chown -R $USER:$USER /mnt/SN750-1TB
```
