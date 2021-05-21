#!/usr/bin/env python3

import os
import re
from xattr import xattr

# Each line is a filename,tagname pair. If a file has more than one tag, it will be printed several times

# Set the directory you want to start from
rootDir = '/run/media/archive_media/archive_media/p/o'

# Ignore hash attributes
attribute_md5 = 'user.md5'
attribute_dhash = 'user.dhash'

for root, dirs, files in os.walk(rootDir):
  for name in files:
    filename = os.path.join(root, name)
    xf = xattr(filename)
    for a in xf.list():
      if ((a != attribute_md5) and (a != attribute_dhash)):
        print(filename + ',' + re.sub(r'person.', '', re.sub(r'user.', '', a)))
