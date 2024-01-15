#!/bin/sh -e
#
#  Copyright 2020, Roger Brown
#
#  This file is part of rhubarb pi.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# $Id: package.sh 9 2021-01-11 21:07:00Z rhubarb-geek-nz $
#

VERSION=3.0.1

PKGNAME=pjac
APPNAME=acme_client
GITREPO=$APPNAME

rm -rf data "$GITREPO"

cleanup()
{
	rm -rf tmp data control data.tar.gz control.tar.gz "$GITREPO" debian-binary
}

first()
{
	echo "$1"
}

trap cleanup 0

git clone https://github.com/porunov/$GITREPO.git "$GITREPO"

(
	set -e

	cd "$GITREPO"
	git checkout "v$VERSION"
	./gradlew clean build	
)

for d in lib bin
do
	mkdir -p data/opt/$PKGNAME/$d
done

cat >data/opt/$PKGNAME/bin/$APPNAME <<EOF
#!/bin/sh -e
if test -n "\$JAVA_HOME"
then
        JAVA="\$JAVA_HOME/bin/java"
else
        JAVA=java
fi
exec "\$JAVA" -jar /opt/$PKGNAME/lib/$APPNAME.jar \$@
EOF

chmod +x data/opt/$PKGNAME/bin/$APPNAME

mv "$GITREPO/build/libs/$APPNAME.jar" data/opt/$PKGNAME/lib

find data

SIZE=`du -sk data`
SIZE=`first $SIZE`

mkdir control

cat >control/control <<EOF
Package: $PKGNAME
Version: $VERSION
Architecture: all
Maintainer: rhubarb-geek-nz@users.sourceforge.net
Recommends:
Section: misc
Priority: extra
Homepage: https://github.com/porunov/acme_client
Installed-Size: $SIZE
Description: Porunov Java ACME Client
EOF

cat control/control

cat >control/postinst <<EOF
#!/bin/sh -e
mkdir -p /var/log/acme
if test ! -f /var/log/acme/acme.log
then
	touch /var/log/acme/acme.log
	chmod ugo+rw /var/log/acme/acme.log
fi
EOF

chmod +x control/postinst

echo "2.0" >debian-binary

for d in data control
do
	(
		set -e
		cd $d
		tar --owner=0 --group=0 --create --gzip --file ../$d.tar.gz ./*
	)
done

ar r "$PKGNAME"_"$VERSION"_all.deb debian-binary control.tar.gz data.tar.gz
