# In my setup, this is IO bound. We could compute hashes paralell, but the
# whole process is likely IO bound

# Mount
mnt-archive_media

cd /mnt
sudo ln -sf "$MNTDIR/archive_media/archive_media/p"

cd /home/mediadb/db

# Uncomment for full re-indexing
#nohup find /mnt/p/ -type f -exec my-picture-hash.sh {} \; > allraw.index
#cat allraw.index | sort -t ','  -k 3 > all.index
#rm allraw.index
#exit 0

# All files to index
find /mnt/p/ -type f | sort > /tmp/allfiles

cat all.index  | cut -d',' -f3 | sort > /tmp/alreadyindexed
comm -2 -3 /tmp/allfiles /tmp/alreadyindexed > /tmp/filesneedtobereindexed
comm -1 -3 /tmp/allfiles /tmp/alreadyindexed > /tmp/filescannotbefound

cat all.index > /tmp/newall.index
if [ -s "/tmp/filescannotbefound" ]; then
  grep -vf /tmp/filescannotbefound all.index > /tmp/newall.index
fi

touch /tmp/allhashes
if [ -s "/tmp/filesneedtobereindexed" ]; then
  cat /tmp/filesneedtobereindexed | xargs -d'\n' -n 1 my-picture-hash.sh > /tmp/allhashes
fi

# Sort all index file based on filepath, at least this makes it deterministic
cat /tmp/newall.index /tmp/allhashes | sort -t ','  -k 3 > all.index

# Used to quickly check if file is already in the database or not
cat all.index  | cut -d, -f2 | sort | uniq > all_sorted_index.md5

cat all.index | my-picture-sanitize.sh > main.index
cat main.index | cut -d, -f1 > main.md5
cat main.index | cut -d',' -f1-2 > main.md5.date
cat main.index | cut -d, -f1,3 > main.md5.name

# Recomputer list of starred files
grep -f main.md5.starlist all.index | cut -d',' -f3 | sed -e 's/\/mnt\/p\/o\///g' > starlist
