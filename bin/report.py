#!/usr/bin/env python3

import subprocess
import os
import csv
import re
import sqlite3
import shlex

# Todo Handle ,, in csv file (when there is no value)
def process_line (line):
  ret = " ("
  i = line.pop(0)
  for j in line:
    i = re.sub("'","''", i)
    if i.lower() in ['null']:
      ret += "%s," % i
    else:
      ret += "'%s'," % i
    i=j

  i = re.sub("'","''", i)
  if i.lower() in ['null']:
    ret += "%s" % i
  else:
    ret += "'%s'" % i

  ret += ")\n"
  return ret


def process_cvs (data):
#    print (data)
#    csvreader = csv.reader(data)

    dialect = csv.Sniffer().sniff('1,2\n')
    print (dialect)
    csvreader = csv.reader (data, dialect)

    for row in csvreader:
      print(', '.join(row))

#    for line in csvreader:
#      print(line)
    return

    # Ignore header for now
    header = next(csvreader)
    #if not (tablename,) in tables:
 #     f_sql.write ('CREATE TABLE "%s" %s;\n' % (tablename, process_line(header)))
    print (header)

 #   f_sql.write ('INSERT INTO "%s" VALUES\n' % tablename)

    line = next(csvreader)
    for nextline in csvreader:
 #     f_sql.write ("%s," % process_line (line))
      print (line)
      line = nextline

 #   f_sql.write ("%s;" % process_line (line))
 #   f_sql.close()

 #   os.system("sqlite3 /home/user/0/databases/new.sqlite < %s" % sqlfilename)
 #   os.system("rm %s" % sqlfilename)

def process_cvs_file (csvfile):
  tablename = os.path.basename (csvfile)
  tablename = os.path.splitext(tablename)[0]
  sqlfilename = tablename + ".sql"
  print(("Processing %s" % tablename))

  f_sql=open(sqlfilename, 'w+')

  with open(csvfile) as f_csv:
    process_cvs(f_csv)

cmd = 'gpg --decrypt /Volumes/data/Users/user/.password-store/docs/finance/account.csv.gpg'
gpg = subprocess.Popen(shlex.split(cmd), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
data = gpg.communicate()[0].decode('utf-8')

#print(data)
process_cvs(data.split('\n'))

# Remove old database as we're regenerating
#os.system('rm /home/user/0/databases/new.sqlite 2>/dev/null')
#os.system('touch /home/user/0/databases/new.sqlite')

# Import all sql files
#os.system('find ~/0 -name "*.sql" -exec cat {} \; | sqlite3 /home/user/0/databases/new.sqlite')

# Print all tables
#con = sqlite3.connect('/home/user/0/databases/new.sqlite')
#cursor = con.cursor()
#cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
#tables = cursor.fetchall()

# Import all CSV files
#p = subprocess.Popen('find ~/0 -name "*.csv"', shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
#for csvfile in p.stdout.readlines():
#  csvfile = csvfile.decode("utf-8").rstrip('\r\n')
#  process_cvs (csvfile)

# Update
#os.system('sqldiff /home/user/0/databases/0.sqlite /home/user/0/databases/new.sqlite')
#os.system('mv /home/user/0/databases/new.sqlite /home/user/0/databases/0.sqlite')
