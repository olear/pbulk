#!/bin/sh

# Setup pbulk on Linux

# Copyright 2014 Ole Andre Rodlie <olear@dracolinux.org> 
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

echo "WARNING! pbulk needs a clean system, and will modify several files/folders on your system."
sleep 5

# Clean if requested
if [ "$1" == "clean" ]; then
  userdel pbulk
  rm -rf /home/{pbulk,packages,reports} /usr/pkg* /var/db/pkg*
  exit 0
fi

# Build if requested
if [ "$1" == "build" ]; then
  /usr/pkg_bulk/bin/bulkbuild
  exit 0
fi

if [ "$1" != "setup" ]; then
  echo "Usage: $0 clean|setup|build current"
  exit 0
fi

# Install needed system packages
if [ -f /etc/redhat-release ]; then
  yum -y install xz screen mailx wget gcc-c++ ncurses-devel
fi

# Download and extract pkgsrc
if [ ! -f pkgsrc.tar.xz ]; then
  BRANCH=stable
  if [ "$2" == "current" ]; then
    BRANCH=current
  fi
  wget ftp://ftp.netbsd.org/pub/pkgsrc/$BRANCH/pkgsrc.tar.xz || exit 1
fi
tar xvf pkgsrc.tar.xz -C /usr || exit 1

# pbulk bootstrap
cd /usr/pkgsrc/bootstrap 
./bootstrap --prefer-pkgsrc=yes --prefix=/usr/pkg_bulk --pkgdbdir=/usr/pkg_bulk/.pkgdb || exit 1

# pbulk install
cd /usr/pkgsrc/pkgtools/pbulk
/usr/pkg_bulk/bin/bmake install || exit 1

# Clean
rm -rf /usr/pkgsrc/bootstrap/work /usr/pkgsrc/*/*/work /usr/pkgsrc/packages/* /usr/pkgsrc/distfiles/*

# Bootstrap
cat <<EOF > /usr/pkgsrc/bootstrap/mk-fragment.conf
WRKOBJDIR = /home/pbulk/scratch
PKGSRCDIR = /usr/pkgsrc
DISTDIR = /home/pbulk/distfiles
PACKAGES = /home/pbulk/packages

FAILOVER_FETCH=	yes
X11_TYPE= modular
SKIP_LICENSE_CHECK= yes
ALLOW_VULNERABLE_PACKAGES= yes

PKG_DEVELOPER?= yes
MAKE_JOBS=4
EOF

cd /usr/pkgsrc/bootstrap
./bootstrap --prefer-pkgsrc=yes --mk-fragment /usr/pkgsrc/bootstrap/mk-fragment.conf --gzip-binary-kit /usr/pkgsrc/bootstrap/binary-kit.tar.gz || exit 1

# Clean
rm -rf /usr/pkg /var/db/pkg /usr/pkgsrc/bootstrap/work /usr/pkgsrc/*/*/work

# Setup user and perms
useradd -m -U pbulk || exit 1
mkdir -p /home/pbulk/scratch /home/pbulk/distfiles /home/pbulk/packages /home/pbulk/bulklog
touch /home/pbulk/limited_list
chown pbulk:pbulk -R /home/pbulk

# Add default config
if [ -f pbulk.conf ]; then
  cat pbulk.conf > /usr/pkg_bulk/etc/pbulk.conf || exit 1
fi

echo
echo "pbulk setup done, edit /usr/pkg_bulk/etc/pbulk.conf and/or /home/pbulk/limited_list."
echo

exit 0
