#!/usr/bin/env python3

#Reads the digikam db and sets them as extended attributes

import os
import re
import sqlite3
from xattr import xattr

# Set the directory you want to start from
rootDir = '/run/media/archive_media/archive_media/p/o'

SQLITE_DB_PATH = '/home/mediadb/digikam/digikam4.db'

conn = sqlite3.connect(SQLITE_DB_PATH)
cursor = conn.cursor()

# load Albums
cursor.execute("SELECT id, relativePath FROM Albums a")

albums=dict()
for row in cursor:
  albums[row[0]]=row[1]

# load Tags
cursor.execute("SELECT id, name FROM Tags")

imagetags=dict()
imagetags_toid=dict()

for row in cursor:
  imagetags[row[0]]=row[1]
  imagetags_toid[row[1]]=row[0]

attribute_dhash = 'user.dhash'
rootDir = '/run/media/archive_media/archive_media/p/o'

# Iterate over Images table
cursor.execute("SELECT i.album, i.name, i.uniqueHash FROM Images i")

for row in cursor:
  filename = rootDir + '/' + albums[row[0]][1:] + '/' + row[1]
  xf = xattr(filename)
  if not((xf.has_key(attribute_dhash))):
    xf.set(attribute_dhash, bytes(row[2], 'utf-8'))

# Iterate over ImageTags table
cursor.execute("SELECT i.album, i.name, t.tagId, t.imageId FROM ImageTags t LEFT JOIN Images i ON t.imageid = i.id")

attribute_person = 'user.person.'

for row in cursor:
    tag = imagetags[row[2]]
    if (tag == 'Scanned for Faces'):
      continue

    if (tag == 'Pick Label None'):
      continue

    if (tag == 'Color Label None'):
      continue

    if (tag == 'facehenrik'):
      tag = 'henrik'

    if (tag == 'star'):
      attribute = 'user.' + tag
    else:
      attribute = 'user.person.' + tag

    filename = rootDir + '/' + albums[row[0]][1:] + '/' + row[1]
    xf = xattr(filename)
    if not((xf.has_key(attribute))):
      print (filename + " " + attribute)
      xf.set(attribute, b'')

# Take xattr and write it back to the digikam db

# Ignore hash attributes
attribute_md5 = 'user.md5'

for root, dirs, files in os.walk(rootDir):
  for name in files:
    filename = os.path.join(root, name)
    xf = xattr(filename)
    for a in xf.list():
      if ((a != attribute_md5) and (a != attribute_dhash)):
        tag=re.sub(r'person.', '', re.sub(r'user.', '', a))
        dhash=xf.get(attribute_dhash).decode("utf-8")
        t = (dhash,)
        cursor.execute('SELECT id FROM images WHERE uniqueHash=?', t)
        row=cursor.fetchone()
        imageid=row[0]
        cursor.execute("SELECT imageId FROM ImageTags WHERE imageId = '%s' AND tagId = '%s' " % (imageid, imagetags_toid[tag]))
        row=cursor.fetchone()
        if (row == None):
          print (filename + " " + tag + " " + imageid + " " + imagetags_toid[tag])
          cursor.execute("INSERT INTO ImageTags (imageid, tagid) VALUES (:imageId, :tagId)", {'imageId': imageid, 'tagId': imagetags_toid[tag]})

conn.commit()
conn.close()
