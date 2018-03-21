#!/bin/sh

# http://wiki.nginx.org/Install
#aptitude install nginx
apt-get update -qq
apt-get install -y -qq gcc make cpanminus
apt-get install -y -qq fop libservlet2.4-java # Для xsl-fo => pdf
apt-get install -y -qq carton
