---
date:
  created: 2025-01-16
---

# CSV to JSON with `column`
The `column` [tool is pretty neat](https://github.com/util-linux/util-linux/blob/c05a1b8b577a2db634df91f75a6f6053fb3c50a9/text-utils/column.1.adoc).
It allows you to format text in columns (how surprising). Less known fact is that itd
can also show output in JSON format. This is useful when you need quick way to convert
text or even CSV to JSON.

I've learned about it form this [amazing YouTube video](https://www.youtube.com/watch?v=uL7KvRskeog) by
[Veronica Explains](https://www.youtube.com/@VeronicaExplains).

<!-- more -->

## Preparation
Let's start with download of Nederlandse Spoorwagen stations open data from:

https://www.rijdendetreinen.nl/en/open-data/stations

```bash
curl -s https://opendata.rijdendetreinen.nl/public/stations/stations-2023-09.csv > stations-2023-09.csv
```

Check the first 5 rows of the file:

```bash
 head -n 5 stations-2023.csv
```
It should look like this:

```csv
id,code,uic,name_short,name_medium,name_long,slug,country,type,geo_lat,geo_lng
266,HT,8400319,"Den Bosch",'s-Hertogenbosch,'s-Hertogenbosch,s-hertogenbosch,NL,knooppuntIntercitystation,51.69048,5.29362
269,HTO,8400320,"Dn Bosch O","'s-Hertogenb. O.","'s-Hertogenbosch Oost",s-hertogenbosch-oost,NL,stoptreinstation,51.700553894043,5.3183331489563
227,HDE,8400388,"'t Harde","'t Harde","'t Harde",t-harde,NL,stoptreinstation,52.4091682,5.893611
8,AHBF,8015345,Aachen,"Aachen Hbf","Aachen Hbf",aachen-hbf,D,knooppuntIntercitystation,50.7678,6.091499
```

## CSV to JSON conversion
The command may look like arcane spell, but it's actually quite simple:
```bash
# Skip the first line of the input file (header) with `tail -n +2`
#
# For the column options:
# -t to format the output as a table
# -s ',' to specify the delimiter in the input file
# -N to specify the column names (we take the first line of the input csv file)
# -J to get JSON output
# -n to specify the key in the JSON output: {"name": [{<row1>}, {<row2>}, ...]}
# otherwise it would be {"table": {<row1>, <row2>, ...}}
#
# To provide column with the column names, we use the first line of the input file
# with head
tail -n +2 stations-2023-09.csv | column -t -s ',' -N $(head -n 1 stations-2023-09.csv) -J -n "stations" > stations-2023-09.json
```

That's it! Now you have the data in JSON without any extra tools.
You can check the first two rows from the output with `jq`:
```bash
jq '.stations | .[:2]' stations-2023-09.json
```
It should show:

```json
[
  {
    "id": "266",
    "code": "HT",
    "uic": "8400319",
    "name_short": "\"Den Bosch\"",
    "name_medium": "'s-Hertogenbosch",
    "name_long": "'s-Hertogenbosch",
    "slug": "s-hertogenbosch",
    "country": "NL",
    "type": "knooppuntIntercitystation",
    "geo_lat": "51.69048",
    "geo_lng": "5.29362"
  },
  {
    "id": "269",
    "code": "HTO",
    "uic": "8400320",
    "name_short": "\"Dn Bosch O\"",
    "name_medium": "\"'s-Hertogenb. O.\"",
    "name_long": "\"'s-Hertogenbosch Oost\"",
    "slug": "s-hertogenbosch-oost",
    "country": "NL",
    "type": "stoptreinstation",
    "geo_lat": "51.700553894043",
    "geo_lng": "5.3183331489563"
  }
]
```

## Classical use cases
If you didn't heard of `column` before, you may find it useful for other table formatting tasks.
For example show the content of the `/etc/systemd` directory in columns with 60 characters width:
```bash
ls /etc/systemd | column -c 60
```

```
coredump.conf		    oomd.conf
homed.conf		        pstore.conf
journald.conf		    resolved.conf
journal-remote.conf     sleep.conf
journal-upload.conf	    system
logind.conf		        system.conf
logind.conf.pacnew	    timesyncd.conf
network			        user
networkd.conf		    user.conf
```

But the table formatting in the JSON conversion example is also very powerful by itself:
```bash
cat /etc/passwd | column -t -s ':' -N User,Pass,UID,GID,Description,Home,Shell
```

This will show you the content of the `/etc/passwd` file in a nice table format:
```
User                    Pass  UID    GID    Description                    Home              Shell
root                    x     0      0                                     /root             /usr/bin/bash
bin                     x     1      1                                     /                 /usr/bin/nologin
daemon                  x     2      2                                     /                 /usr/bin/nologin
mail                    x     8      12                                    /var/spool/mail   /usr/bin/nologin
ftp                     x     14     11                                    /srv/ftp          /usr/bin/nologin
http                    x     33     33                                    /srv/http         /usr/bin/nologin
nobody                  x     65534  65534  Kernel Overflow User           /                 /usr/bin/nologin
dbus                    x     81     81     System Message Bus             /                 /usr/bin/nologin
```

With named columns we can now rearrange their order with the `-O` option and even
hide some columns with the `-H` option:
```bash
cat /etc/passwd | column -t -s ':' -N User,Pass,UID,GID,Description,Home,Shell \
-O UID,GID,User,Shell \
-H Pass,Description,Home
```

The output will look like this:
```
UID    GID    User                    Shell
0      0      root                    /usr/bin/bash
1      1      bin                     /usr/bin/nologin
2      2      daemon                  /usr/bin/nologin
8      12     mail                    /usr/bin/nologin
14     11     ftp                     /usr/bin/nologin
33     33     http                    /usr/bin/nologin
```
