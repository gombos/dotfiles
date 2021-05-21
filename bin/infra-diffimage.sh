kpartx -a -v $1
sleep 1
kpartx -a -v $2
sleep 1

mkdir -p /mnt/tmp1
mkdir -p /mnt/tmp2

mount /dev/mapper/loop0p1 /mnt/tmp1
mount /dev/mapper/loop1p1 /mnt/tmp2
#exit # for debug

#todo - kill /var/log
#todo - /etc/alternatives
#todo - __pycache__
#todo - make sure exists - Only in /mnt/tmp1/var/lib/sudo/lectured: user
#Only in /mnt/tmp1/var/lib/sudo: ts

#PRUNE_IMAGE=yes

if [ "$PRUNE_IMAGE" == yes ]; then
    rm -rf /mnt/tmp1/root/.bash_history
    rm -rf /mnt/tmp1/var/lib/systemd/random-seed
    rm -rf /mnt/tmp1/var/lib/dpkg/status-old
fi

diff -rq /mnt/tmp1 /mnt/tmp2 2>/dev/null | grep -v "special file"

umount /mnt/tmp1
umount /mnt/tmp2

kpartx -d -v $2
kpartx -d -v $1

