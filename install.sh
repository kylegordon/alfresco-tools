#!/bin/bash

# SLES Quick Start Script for Alfresco 3.4/4.0
# Based on the Ubuntu EC2 Quick Start Script for Alfresco 3.4/4.0 from
#
# Initial author: Will Abson
# Further changes by: Kyle Gordon
# 
# TODO
#
# * Test JMX connections inbound
# * Support use of official Alfresco packages from partner repository
# * Allow packaging of sample content
#
# Ports required
#
# * 80 - HTTP
# * 25 and 143 for SMTP-in and IMAP (if enabled)
# * 8080 (admin purposes only)
# * 7070 - SharePoint protocol support
# * 50500 - JMX remote monitoring and control

# Begin configuration

# The base URL to download from, and the version of Alfresco in use
alf_base_url="http://deployment_server.nes.scot.nhs.uk/instserv/software/alfresco/"
alf_version_suffix="-4.0.2.9"
alf_edition="enterprise"

swftools_rpm="swftools-0.9.1-5.2.x86_64.rpm"
imagemagick_rpm="ImageMagick-6.4.3.6-7.18.x86_64.rpm"
libmagick_rpm="libMagick++1-6.4.3.6-7.18.x86_64.rpm"
libmagickwand_rpm="libMagickWand1-6.4.3.6-7.18.x86_64.rpm"
openoffice_tarball="Apache_OpenOffice_incubating_3.4.1_Linux_x86_install-rpm_en-GB.tar.gz"

TOMCAT_VER="apache-tomcat-6.0.35"
TOMCAT_TAR="$TOMCAT_VER.tar.gz"

BASE_TEMP_DIR="/tmp"
ALF_TEMP_DIR="$BASE_TEMP_DIR/alfresco-temp"
ALF_WAR_PKG="alfresco-war.zip"
ALFRESCO_BASE="/opt/alfresco/"
CATALINA_BASE=/opt/alfresco/tomcat
ALF_RM_VER="2.0.0-111"

memsize=`cat /proc/meminfo | grep MemTotal | awk {'print $2'}`
if [ $memsize -lt 4106527 ]; then
	echo "You have less than 4GB of memory. Please obtain more memory"
	echo "Exiting now"
	exit 0
fi

if [ -z "`grep -i $HOSTNAME /etc/hosts`" ]; then
	echo "You do not have your hostname in /etc/hosts"
	echo "Please correct this and try again"
fi

# End configuration

# Do not edit below this line

# Whether the Share webapp will be installed
alf_install_share=1

# Whether SPP support will be installed
alf_install_vti=1

# Whether DOD modules will be installed
# DOD is the old name for the Records Management module
alf_install_dod=1

# Whether to enable IMAP
alf_enable_imap=1

# Whether to enable FTP
alf_enable_ftp=1

# Whether to enable CIFS
alf_enable_cifs=0

# Whether to enable inbound SMTP - not yet implemented
alf_enable_smtp=0

# Whether or not to add bundled .sample files to shared/classes
alf_install_sample_config=0

# JDK to install
#jdk_version=sun-java6-jdk
jdk_version=default-jdk

# Whether to remove the downloaded WAR package after downloading
cleanup_war=1

# FIXME
# Whether to clean up the temp dir contents afterwards
cleanup_after=1

# Detect command-line options and their parameters
p_opt=""
for p in "$@"
do
  if [[ "$p" == --* ]]; then
    p_opt=""
    case "$p" in 
      --no-install-share)
        alf_install_share=0
        ;;
      --no-install-vti)
        alf_install_vti=0
        ;;
      --no-install-dod)
        alf_install_dod=0
        ;;
      --enable-imap)
        alf_enable_imap=1
        ;;
      --disable-imap)
        alf_enable_imap=0
	;;
      --enable-ftp)
      	alf_enable_ftp=1
	;;
      --disable-ftp)
        alf_enable_ftp=0
	;;
      --enable-cifs)
        alf_enable_cifs=1
        ;;
      --disable-cifs)
        alf_enable_cifs=0
        ;;
      --enable-smtp)
        alf_enable_smtp=1
        ;;
      --install-sample-config)
        alf_install_sample_config=1
        ;;
      --jdk-version)
        ;;
      --no-cleanup-war)
        cleanup_war=0
        ;;
      --no-cleanup)
        cleanup_after=0
        cleanup_war=0
        ;;
      *)
        echo "Unrecognised option $p"
        exit 1
        ;;
    esac
    p_opt="$p"
  else
    case "$p_opt" in
      --jdk-version)
        jdk_version="$p"
        ;;
      --alf-version)
        alf_version_suffix="-$p"
        ;;
      --alf-edition)
        alf_edition="-$p"
        ;;
      --alf-dl-url)
        alf_base_url="-$p"
        ;;
      *)
        echo "Unsupported parameter $p"
        exit 1
        ;;
    esac
    p_opt=""
  fi
done

#ALF_DL_URL="$alf_base_url/alfresco-enterprise-war$alf_version_suffix.tar.gz"
# Construct individual download URLs
case "$alf_version_suffix" in
  *-4*)
	echo "alf_version_suffix is a 4"
    ALF_DL_URL="$alf_base_url/alfresco-$alf_edition$alf_version_suffix.zip"
    ALF_VTI_MODULE_URL="$alf_base_url/alfresco-$alf_edition-spp$alf_version_suffix.zip"
    ALF_DOD_MODULE_URL="$alf_base_url/alfresco-rm-$ALF_RM_VER.zip"
    ;;
  *-3.4*)
	echo "alf_version_suffix is a 3.4"
    ALF_DL_URL="$alf_base_url/alfresco-$alf_edition$alf_version_suffix.zip"
    ALF_VTI_MODULE_URL="$alf_base_url/alfresco-$alf_edition-spp$alf_version_suffix.zip"
    ALF_DOD_MODULE_URL="$alf_base_url/alfresco-rm-$ALF_RM_VER.zip"
    ;;
  *)
	echo "alf_version_suffix is unknown"
    ALF_DL_URL="$alf_base_url/alfresco-enterprise-war$alf_version_suffix.zip"
    ALF_MMT_URL="$alf_base_url/alfresco-mmt$alf_version_suffix.jar"
    ALF_VTI_MODULE_URL="$alf_base_url/vti-module.amp"
    # DOD files now have version number in the file name for 3.3e
    ALF_DOD_MODULE_URL="$alf_base_url/alfresco-rm-$ALF_RM_VER.zip"
    ALF_DOD_SHARE_MODULE_URL="$alf_base_url/alfresco-rm-$ALF_RM_VER.zip"
esac

# Cache for Alfresco Network credentials
alf_network_user=""
alf_network_pw=""
alf_network_logged_in=0

# APT sources vars
#apt_repo_url=`grep '^deb ' /etc/apt/sources.list | head -1 | cut -d ' ' -f 2`
#apt_repo_name=`grep '^deb ' /etc/apt/sources.list | head -1 | cut -d ' ' -f 3`
#ubuntu_release=$apt_repo_name

function dl_package {
  # If the download URL uses Network then attempt to log in
  if [ -n "`echo $1 | grep network.alfresco.com`" ]; then
    echo "Downloading '$1' from Alfresco Network"
    if [ $alf_network_logged_in -eq 0 ]; then
      alf_network_log_in
    fi
    # We should be logged in now
    if [ $alf_network_logged_in -eq 0 ]; then
      echo "Unable to log in to Alfresco Network"
      exit 1
    fi
    echo "Starting download"
    curl --silent --cookie network-cookies.txt --cookie-jar network-cookies.txt --dump-header headers.txt $1 -o $2
    httpstatus=`cat headers.txt | head -1| cut -d ' ' -f 2`
    if [ "$httpstatus" != "200" ]; then
      echo "Error: Got HTTP status $httpstatus"
      exit 1
    fi
    rm headers.txt
  fi

  # Otherwise do a plain HTTP download
  if [ -z "`echo $1 | grep network.alfresco.com`" ]; then
    echo "Downloading '$1' via HTTP to '$2'"
    curl --silent --dump-header headers.txt $1 -o $2
    httpstatus=`cat headers.txt | head -1| cut -d ' ' -f 2`
    if [ "$httpstatus" != "200" ]; then
      echo "Error: Got HTTP status $httpstatus"
      exit 1
    fi
    rm headers.txt
  fi
}

# Copy WAR file from an exploded Alfresco ZIP package
function copy_war {
  if [ -f "$1/$2" ]; then
    cp -p "$1/$2" $3
  else
    if [ -f "$1/web-server/webapps/$2" ]; then
      cp -p "$1/web-server/webapps/$2" $3
    else
      echo "Could not find webapp '$2' in '$1'"
    fi
  fi
}

function unpack_war {
  war_file="$1/$2"
  war_dir="$1"/`echo $2 | cut -d . -f 1`
  if [ ! -d "$war_dir" ]; then
    echo "Extracting $war_file into $war_dir"
    mkdir "$war_dir"
    unzip -qq "$war_file" -d "$war_dir"
    chown -R alfresco:alfresco "$war_dir"
  fi
}

function pack_war {
  war_file="$1/$2"
  war_dir="$1"/`echo $2 | cut -d . -f 1`
  echo "Packing $war_dir into $war_file"
  cd "$war_dir"
  chmod -R a+r .
  zip -uq "$war_file" "*"
  chown -R alfresco:alfresco "$war_file"
  cd - >/dev/null
}

function install_amp {
  if [ ! -f /opt/alfresco/bin/alfresco-mmt.jar ]; then
    echo "Module Management Tool not found!"
    exit 1
  fi
  java -jar /opt/alfresco/bin/alfresco-mmt.jar install "$2" "$1"
}

function set_property {
  if [ -f "$1" ]; then
    esckey=${2//\./\\.}
    existing=`grep "^#*\s*$esckey=.*" "$1"`
    if [ -n "$existing" ]; then
      escval=${3//\//\\\/}
      escval=${escval//\./\\.}
      sed -i "s/#*\s*$esckey=.*/$esckey=$escval/" "$1"
    else
      echo "$2=$3" >> "$1"
    fi
  else
    echo "$2=$3" >> "$1"
  fi
}

#function install_bootstrap_data {
#  mkdir "$2"
#  unzip "$1" -d "$2"
#  cp "alfresco-bootstrap-data.sh" "/etc/init.d/alfresco-bootstrap-data"
#  update-rc.d "alfresco-bootstrap-data" defaults 98 02
#}

# Install the Module Management Tool from the WAR package. If it is not found
# then download it instead.
function install_mmt_tool {
  MMT_JAR="/opt/alfresco/bin/alfresco-mmt.jar"
  if [ ! -f "$MMT_JAR" ]; then 
    mkdir -p /opt/alfresco/bin/
    if [ -f "$ALF_TEMP_DIR/commands/bin/alfresco-mmt.jar" ]; then
      cp "$ALF_TEMP_DIR/commands/bin/alfresco-mmt.jar" "$MMT_JAR"
    else
      if [ -f "$ALF_TEMP_DIR/bin/alfresco-mmt.jar" ]; then
        cp "$ALF_TEMP_DIR/bin/alfresco-mmt.jar" "$MMT_JAR"
      else
        echo "Downloading Module Management Tool"
        dl_package "$ALF_MMT_URL" "$MMT_JAR"
      fi
    fi
    chown alfresco:alfresco "/opt/alfresco/bin/alfresco-mmt.jar"
  fi
}

# Copy sample config files from the WAR package
function copy_extension_config {
  # Pre 3.3 WAR package
  if [ -d "$1/extensions/extension" ]; then
    mkdir "$2/shared/classes/alfresco"
    cp -pr "$1/extensions/extension" "$2/shared/classes/alfresco"
  else
    # 3.3 WAR (include alfresco-global.properties)
    if  [ -d "$1/extensions/alfresco" ]; then
      cp -pr "$1/extensions/alfresco"* "$2/shared/classes"
    else
      # 3.4 WAR
      if [ -d "$1/web-server/shared/classes" ]; then
        cp -pr "$1/web-server/shared/classes/alfresco"* "$2/shared/classes"
      else
        echo "Could not find extensions in '$1'"
      fi
    fi
  fi
  set_ownership $2/shared/classes/alfresco*
}

function set_ownership {
  chown -R alfresco:alfresco $1
}

# Check user if root
if [ "$(whoami)" != "root" ]; then
   echo "This script requires root permissions to run"
   exit 1
fi

# Configure the alfresco user - a home directory and a proper shell are needed to run OpenOffice
echo "Configuring alfresco user"
if [ ! -d /home/alfresco ]; then 
	groupadd alfresco
	useradd -m -r -g alfresco -p alfresco alfresco
fi
# mkdir /home/alfresco; fi
#chown alfresco:alfresco /home/alfresco
#usermod --home /home/alfresco --shell /bin/bash alfresco

#
# Install dependencies
#

echo "Updating repositories"
zypper refresh

# Set up a space to work in
if [ ! -d "$ALF_TEMP_DIR" ]; then mkdir "$ALF_TEMP_DIR"; fi

dl_package "$alf_base_url/$TOMCAT_TAR" "$ALF_TEMP_DIR/$TOMCAT_TAR"
#dl_package "$alf_base_url/NHS_Education_for_Scotland-ent41.lic" "$ALF_TEMP_DIR/NHS_Education_for_Scotland-ent41.lic"

if [ -x '/usr/lib64/jvm/jre-1.6.0-ibm' ]; then
	echo "Removing IBM Java"
	zypper remove -y java-1_6_0-ibm-fonts
fi

# Install Sun Java 1.6 
echo "Checking for Java 1.6.0"
if [ ! -x '/usr/java/jre1.6.0_35/' ]; then
        zypper install -y $alf_base_url/jre-6u35-linux-amd64.rpm
fi
java_home="/usr/java/jre1.6.0_35/"

# We should probably be more graceful about this. One day
echo "Purging PostgreSQL if it exists"
if [ 'which postgres' ]; then
	zypper remove -y postgresql
	zypper remove -y postgresql91
        rm -rf /var/lib/pgsql	
fi

echo "Checking for PostgreSQL"
if [ ! `which postgres` ]; then
	zypper install -y postgresql-server
	/etc/init.d/postgresql start
fi
# Configure PostgreSQL to start automatically
chkconfig postgresql on

# Switch to Postgresql user, and run psql whilst selecting the postgres database
# Change the password for the default postgres user
sudo -u postgres psql postgres << EOF
ALTER USER postgres WITH PASSWORD 'postgres';
EOF

# Create the Alfresco user, create the alfresco database, 
# and let the Alfresco user have full rights on the Alfresco DB
sudo -u postgres psql postgres << EOF
CREATE USER alfresco WITH PASSWORD 'alfresco';
CREATE DATABASE alfresco OWNER alfresco ENCODING 'UTF8';
GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;
EOF

# We do this at the end, as otherwise we'd need a password to log in to psql
echo "Configuring PostgreSQL authentication"
/etc/init.d/postgresql stop
sed -i s/ident\ sameuser/md5/ /var/lib/pgsql/data/pg_hba.conf
sed -i s/ident/md5/ /var/lib/pgsql/data/pg_hba.conf
sed -i s/#listen_addresses\ \=\ \'localhost\'/listen_addresses\ \=\ \'*\'/ /var/lib/pgsql/data/postgresql.conf
/etc/init.d/postgresql start

#echo "Installing Apache HTTPd"
#apt-get --yes -qq install apache2

echo "Checking for OpenOffice.org"
if [ ! -x /opt/openoffice.org3/program/soffice ]; then
	mkdir $ALF_TEMP_DIR/openoffice/
	dl_package $alf_base_url/$openoffice_tarball $ALF_TEMP_DIR/openoffice/$openoffice_tarball
	tar -zxf $ALF_TEMP_DIR/openoffice/$openoffice_tarball -C $ALF_TEMP_DIR/openoffice/
	zypper install -y $ALF_TEMP_DIR/openoffice/en-GB/RPMS/*.rpm
fi

echo "Checking for ImageMagick"
if [ ! `which convert` ]; then
	zypper install -y "$alf_base_url/$libmagickwand_rpm" "$alf_base_url/$libmagick_rpm" "$alf_base_url/$imagemagick_rpm"
fi

echo "Checking for zip"
if [ ! `which zip` ]; then
	zypper install -y zip
fi

echo "Checking for unzip"
if [ ! `which unzip` ]; then
        zypper install -y unzip
fi

echo "Checking for swftools"
if [ ! `which pdf2swf` ]; then
  # swftools from https://build.opensuse.org/package/show?package=swftools&project=home%3Alijews
  zypper install -y "$alf_base_url/$swftools_rpm"
fi

#apt-get --yes -qq install ec2-ami-tools
#apt-get --yes -qq install checkinstall

# Stop Tomcat ready for changes to webapp files and config
#echo "Stopping Tomcat ready for main installation"
#/etc/init.d/tomcat6 stop

# Download WAR package
echo "Downloading Alfresco WAR package as $ALF_WAR_PKG"
if [ ! -f "$ALF_WAR_PKG" ]; then
  dl_package "$ALF_DL_URL" "$ALF_WAR_PKG"
fi

  # Extract Alfresco files
  echo "Extracting downloaded files"
  case "$ALF_WAR_PKG" in
    *.zip)
      echo "Unzipping $ALF_WAR_PKG"
      unzip -q "$ALF_WAR_PKG" -d "$ALF_TEMP_DIR"
      ;;
    *.tar.gz)
      echo "Untarring $ALF_WAR_PKG"
      tar -xz -f "$ALF_WAR_PKG" -C "$ALF_TEMP_DIR"
      ;;
    *)
      echo "Archive not a supported format: $ALF_WAR_PKG"
      exit 1
  esac
  if [ $cleanup_war -eq 1 ]; then rm "$ALF_WAR_PKG"; fi

# Create directory structures for Alfresco
if [ ! -d /opt/alfresco ]; then mkdir /opt/alfresco; fi
if [ ! -d $CATALINA_BASE/webapps ]; then mkdir -p $CATALINA_BASE/webapps; fi
if [ ! -d /var/log/alfresco ]; then mkdir /var/log/alfresco; fi
chown alfresco:alfresco /var/log/alfresco/
chown alfresco:alfresco /opt/alfresco/

echo "Extracting Tomcat"
tar -zxf $ALF_TEMP_DIR/$TOMCAT_TAR -C $ALF_TEMP_DIR/
echo "Moving tomcat"
mv $ALF_TEMP_DIR/$TOMCAT_VER/* $CATALINA_BASE/
echo "Applying Alfresco tomcat overlay"
cp -r $ALF_TEMP_DIR/web-server/* $CATALINA_BASE/

# Install MMT
install_mmt_tool

# Copy WAR files into place and extract if necessary
echo "Copying WAR files into place and unpacking"
if [ ! -f $CATALINA_BASE/webapps/alfresco.war ]; then
  copy_war "$ALF_TEMP_DIR" "alfresco.war" "$CATALINA_BASE/webapps/"
fi
if [ "$alf_install_share" -eq 1 -a ! -f $CATALINA_BASE/webapps/share.war ]; then
  copy_war "$ALF_TEMP_DIR" "share.war" "$CATALINA_BASE/webapps/"
fi

# Unpack the WAR files so we can make required log4j config changes
if [ ! -d $CATALINA_BASE/webapps/alfresco ]; then
  unpack_war $CATALINA_BASE/webapps alfresco.war
fi
if [ ! -d $CATALINA_BASE/webapps/share ]; then
  unpack_war $CATALINA_BASE/webapps share.war
fi

# Create and enable use of shared/classes and shared/lib in Tomcat config
if [ ! -d $CATALINA_BASE/shared/classes/alfresco ]; then mkdir -p $CATALINA_BASE/shared/classes/alfresco; fi
if [ ! -d $CATALINA_BASE/shared/lib ]; then mkdir -p $CATALINA_BASE/shared/lib; fi
set_property $CATALINA_BASE/conf/catalina.properties 'shared.loader' '${catalina.base}/shared/classes,${catalina.base}/shared/lib/*.jar'
#if [ ! -L /usr/share/tomcat6/shared ]; then ln -s /var/lib/tomcat6/shared /usr/share/tomcat6/shared; fi
set_ownership $CATALINA_BASE/shared/

# Copy extensions into shared/classes folder
if [ $alf_install_sample_config -a ! -d $CATALINA_BASE/shared/classes/alfresco/extension ]; then
  copy_extension_config "$ALF_TEMP_DIR" "$CATALINA_BASE"
fi

echo "Installing init script"
dl_package $alf_base_url/alfresco.init /etc/init.d/alfresco
chmod +x /etc/init.d/alfresco
chkconfig alfresco on

echo "Configuring Alfresco"
mkdir -p $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server01
mkdir -p $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server02
mkdir -p $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server03
dl_package $alf_base_url/subsystem-auth-ldap/ldap-context.xml $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server01/server01-context.xml
dl_package $alf_base_url/subsystem-auth-ldap/ldap-context.xml $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server02/server02-context.xml
dl_package $alf_base_url/subsystem-auth-ldap/ldap-context.xml $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server03/server03-context.xml
set_property $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server01/ldap-authentication.properties "ldap.authentication.java.naming.provider.url" "ldap://server01.nes.scot.nhs.uk:389"
set_property $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server02/ldap-authentication.properties "ldap.authentication.java.naming.provider.url" "ldap://server02.nes.scot.nhs.uk:389"
set_property $CATALINA_BASE/shared/classes/alfresco/extension/subsystems/Authentication/ldap/server03/ldap-authentication.properties "ldap.authentication.java.naming.provider.url" "ldap://server03.nes.scot.nhs.uk:389"
chown -R alfresco.alfresco $CATALINA_BASE/shared/classes/alfresco/extension/subsystems

## If there's privileged ports going to be used, get ready to forward them
if [ "$alf_enable_ftp" == "1" ] || [ "$alf_enable_imap" == "1" ] || [ "$alf_enable_cifs" == "1" ] ; then
  sysctl -w net.ipv6.conf.all.forwarding=1
  sysctl -w net.ipv4.conf.all.forwarding=1
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
fi


f=$CATALINA_BASE/shared/classes/alfresco-global.properties

# Edit alfresco-global.properties

set_property "$f" "alfresco.context" "alfresco"
#alfresco.host=${localname}
set_property "$f" "alfresco.host" "alfresco_server.nes.scot.nhs.uk"
set_property "$f" "alfresco.port" "8080"
set_property "$f" "alfresco.protocol" "http"

set_property "$f" "share.context" "share"
#share.host=${localname}
set_property "$f" "share.host" "ecms.nes.scot.nhs.uk"
set_property "$f" "share.port" "8080"
set_property "$f" "share.protocol" "http"

# Index recovery mode
set_property "$f" "index.recovery.mode" "AUTO"
#set_property" $f" "hibernate.default_schema" "NES_ALFRESCO"

# Repository locations
echo "Setting repo locations"
set_property "$f" "dir.root" "/opt/alfresco/alf_data"
#set_property "$f" "dir.keystore" "\${dir.root}/keystore"

# Program locations
echo "Setting program locations"
set_property "$f" "ooo.enabled" "true"
set_property "$f" "ooo.exe" "/opt/openoffice.org3/program/soffice"
set_property "$f" "ooo.user" "/home/alfresco"
set_property "$f" "img.root" "/usr/bin"
set_property "$f" "img.exe" "convert"
set_property "$f" "swf.exe" "pdf2swf"

# Set Database properties
set_property "$f" "db.schema.update" "true"
set_property "$f" "db.driver" "org.postgresql.Driver"
set_property "$f" "db.url" "jdbc:postgresql://localhost:5432/alfresco"
set_property "$f" "db.username" "alfresco"
set_property "$f" "db.password" "alfresco"
#FIXME - Only required for Oracle
#set_property "$f" "db.pool.validate.query" "SELECT 1 FROM DUAL"
#set_property "$f" "db.driver" "oracle.jdbc.OracleDriver"
#set_property "$f" "db.url" "jdbc:oracle:thin:@dbserver.nes.scot.nhs.uk:1521:alf"


# Remote Management Interface Ports
set_property "$f" "avm.rmi.service.port" "50501"
set_property "$f" "avmsync.rmi.service.port" "50502"
set_property "$f" "attribute.rmi.service.port" "50503"
set_property "$f" "authentication.rmi.service.port" "50504"
set_property "$f" "repo.rmi.service.port" "50505"
set_property "$f" "action.rmi.service.port" "50506"
set_property "$f" "wcm-deployment-receiver.rmi.service.port" "50507"
set_property "$f" "monitor.rmi.service.port" "50508"


# JODConverter settings
set_property "$f" "jodconverter.enabled" "true"
set_property "$f" "jodconverter.officeHome" "/opt/openoffice.org3/program"
set_property "$f" "jodconverter.portNumbers" "8100"

# Enable IMAP
if [ "$alf_enable_imap" == "1" ]; then
  set_property "$f" "imap.server.enabled" "true"
  set_property "$f" "imap.server.host" "0.0.0.0"
  set_property "$f" "imap.server.port" "2143"
  iptables -t nat -A PREROUTING -p tcp --dport 143 -j REDIRECT --to-ports 2143
fi

# Disable CIFS, FTP and NFS
if [ "$alf_enable_cifs" == "1" ]; then
  ## Info from http://wiki.alfresco.com/wiki/File_Server_Subsystem_4.0#Running_SMB.2FCIFS_from_a_normal_user_account
  set_property "$f" "cifs.enabled" "false"
  set_property "$f" "cifs.disableNativeCode" "true"
  set_property "$f" "cifs.tcpipSMB.port" "1445"
  set_property "$f" "cifs.netBIOSSMB.namePort" "1137"
  set_property "$f" "cifs.netBIOSSMB.datagramPort" "1138"
  set_property "$f" "cifs.netBIOSSMB.sessionPort" "1139"
  iptables -t nat -A PREROUTING -p tcp --dport 445 -j REDIRECT --to-ports 1445
  iptables -t nat -A PREROUTING -p tcp --dport 139 -j REDIRECT --to-ports 1139
  iptables -t nat -A PREROUTING -p udp --dport 137 -j REDIRECT --to-ports 1137
  iptables -t nat -A PREROUTING -p udp --dport 138 -j REDIRECT --to-ports 1138
fi

if [ "$alf_enable_ftp" == "1" ]; then
  set_property "$f" "ftp.enabled" "true"
  set_property "$f" "ftp.port" "2121"
  iptables -t nat -A PREROUTING -p tcp --dport 21 -j REDIRECT --to-ports 2121
fi

set_property "$f" "nfs.enabled" "false"

# Set host name and port
#set_property "$f" "alfresco.host" "localhost"
#set_property "$f" "alfresco.port" "80"
#set_property "$f" "share.host" "localhost"
#set_property "$f" "share.port" "80"

# Set mail settings
set_property "$f" "notification.email.siteinvite" "true"
set_property "$f" "mail.host" "mailserver.nes.scot.nhs.uk"
set_property "$f" "mail.port" "25"
set_property "$f" "mail.protocol" "smtp"
set_property "$f" "mail.encoding" "UTF-8"
set_property "$f" "mail.from.default" "ecms@nes.scot.nhs.uk"
set_property "$f" "mail.smtp.auth" "false"

# Authentication chain
set_property "$f" "authentication.chain" "alfrescoNtlm1:alfrescoNtlm,server01:ldap,server02:ldap,server03:ldap"

# Sync settings
set_property "$f" "synchronization.syncWhenMissingPeopleLogIn" "true"
set_property "$f" "synchronization.syncOnStartup" "false"

#LDAP Settings
set_property "$f" "ldap.authentication.active" "true"
set_property "$f" "ldap.authentication.allowGuestLogin" "false"
set_property "$f" "ldap.authentication.userNameFormat" ""
set_property "$f" "ldap.authentication.java.naming.factory.initial" "com.sun.jndi.ldap.LdapCtxFactory"
#set_property "$f" "ldap.authentication.java.naming.provider.url" "ldap://ldapserver.nes.scot.nhs.uk:389"
set_property "$f" "ldap.authentication.java.naming.security.authentication" "simple"
set_property "$f" "ldap.authentication.escapeCommasInBind" "false"
set_property "$f" "ldap.authentication.escapeCommasInUid" "false"
set_property "$f" "ldap.authentication.defaultAdministratorUserNames" "alfresco_service,KyleG,DavidL"
set_property "$f" "ldap.synchronization.active" "true"
set_property "$f" "ldap.synchronization.java.naming.security.authentication" "simple"
set_property "$f" "ldap.synchronization.java.naming.security.principal" "cn=alfresco_service,ou=NATIONAL_SERVICES,o=SCPMDE"
set_property "$f" "ldap.synchronization.java.naming.security.credentials" ""
set_property "$f" "ldap.synchronization.queryBatchSize" "0"
set_property "$f" "ldap.synchronization.attributeBatchSize" "0"
set_property "$f" "ldap.synchronization.groupQuery" "(objectclass\=groupOfNames)"
set_property "$f" "ldap.synchronization.groupDifferentialQuery" "(&(objectclass\=groupOfNames)(!(modifyTimestamp<\={0})))"
set_property "$f" "ldap.synchronization.personQuery" "(&(objectclass\=inetOrgPerson)(groupMembership=cn=ECMS_Users,o=SCPMDE))"
set_property "$f" "ldap.synchronization.personDifferentialQuery" "(&(objectclass\=inetOrgPerson)(groupMembership=cn=ECMS_Users,o=SCPMDE)(!(modifyTimestamp<\={0})))"
set_property "$f" "ldap.synchronization.userSearchBase" "o=SCPMDE"
set_property "$f" "ldap.synchronization.groupSearchBase" "o=SCPMDE"
set_property "$f" "ldap.synchronization.modifyTimestampAttributeName" "modifyTimestamp"
set_property "$f" "ldap.synchronization.timestampFormat" "yyyyMMddHHmmss'Z'"
set_property "$f" "ldap.synchronization.userIdAttributeName" "uid"
set_property "$f" "ldap.synchronization.userFirstNameAttributeName" "givenName"
set_property "$f" "ldap.synchronization.userLastNameAttributeName" "sn"
set_property "$f" "ldap.synchronization.userEmailAttributeName" "mail"
set_property "$f" "ldap.synchronization.userOrganizationalIdAttributeName" "o"
set_property "$f" "ldap.synchronization.defaultHomeFolderProvider" "userHomesHomeFolderProvider"
set_property "$f" "ldap.synchronization.groupIdAttributeName" "cn"
set_property "$f" "ldap.synchronization.userTelephoneNumberAttributeName" "telephoneNumber"
set_property "$f" "ldap.synchronization.userFaxNumberAttributeName" "facsimileTelephoneNumber"
set_property "$f" "ldap.synchronization.userPostCodeAttributeName" "postalCode"
set_property "$f" "ldap.synchronization.userTitleAttributeName" "title"
set_property "$f" "ldap.synchronization.userLocationAttributeName" "l"



# Don't think this is needed
# Web client and Share proxy support
#for cf in `find config -name "*$alf_version_suffix.xml"`; do
#  origname=`echo $cf | sed s/$alf_version_suffix// | sed s/config\\\\///`
#  cp $cf $CATALINA_BASE/shared/classes/$origname
#  chown -R alfresco:alfresco $CATALINA_BASE/shared/classes/alfresco
#done

# Change alfresco.log file location in log4j.properties
set_property "$CATALINA_BASE/webapps/alfresco/WEB-INF/classes/log4j.properties" "log4j.appender.File.File" "/var/log/alfresco/alfresco.log"
if [ "$alf_install_share" == "1" ]; then
  set_property "$CATALINA_BASE/webapps/share/WEB-INF/classes/log4j.properties" "log4j.appender.File.File" "/var/log/alfresco/share.log"
fi

# Add updated files back to the WAR
pack_war $CATALINA_BASE/webapps alfresco.war
if [ "$alf_install_share" == "1" ]; then
  pack_war $CATALINA_BASE/webapps share.war
fi

# Install VTI module
if [ "$alf_install_vti" == "1" ]; then
  listvti="$( java -jar /opt/alfresco/bin/alfresco-mmt.jar list $CATALINA_BASE/webapps/alfresco.war | grep org.alfresco.module.vti )"
  if [ -z "$listvti" ]; then
    echo "Installing VTI module"
    case "$ALF_VTI_MODULE_URL" in
      *.amp)
        echo "About to download $ALF_VTI_MODULE_URL"
        dl_package "$ALF_VTI_MODULE_URL" vti-module.amp
	echo "Done downloading"
        install_amp $CATALINA_BASE/webapps/alfresco.war vti-module.amp
        rm vti-module.amp
      ;;
      *.zip)
        echo "Downloading $ALF_VTI_MODULE_URL"
        dl_package "$ALF_VTI_MODULE_URL" vti-module.zip
        unzip -q vti-module.zip "*.amp"
	echo "Unzip complete"
        install_amp $CATALINA_BASE/webapps/alfresco.war alfresco-$alf_edition-spp$alf_version_suffix.amp
        rm alfresco-$alf_edition-spp$alf_version_suffix.amp vti-module.zip
      ;;
    esac
    set_property "$f" "vti.server.port" "7070"
    #set_property "$f" "vti.server.external.host" "${localname}"
    set_property "$f" "vti.server.external.host" "alfresco_server.nes.scot.nhs.uk"
    set_property "$f" "vti.server.external.port" "7070"
    #set_property "$f" "vti.alfresco.alfrescoHostWithPort" "http://localhost"
    #set_property "$f" "vti.share.shareHostWithPort" "http://localhost"
  fi
fi

# Install DOD modules
if [ "$alf_install_dod" == "1" ]; then
  echo "Installing RM modules"
  listdod="$( java -jar /opt/alfresco/bin/alfresco-mmt.jar list $CATALINA_BASE/webapps/alfresco.war | grep org_alfresco_module_dod5015 )"
  if [ -z "$listdod" -a -n "$ALF_DOD_MODULE_URL" ]; then
    echo "Installing Alfresco RM module"
    case "$ALF_DOD_MODULE_URL" in
      *.amp)
        dl_package "$ALF_DOD_MODULE_URL" alfresco-dod5015.amp
        install_amp $CATALINA_BASE/webapps/alfresco.war alfresco-dod5015.amp
        rm alfresco-dod5015.amp
      ;;
      *.zip)
        dl_package "$ALF_DOD_MODULE_URL" alfresco-rm-$ALF_RM_VER.zip
        unzip -q alfresco-rm-$ALF_RM_VER.zip "*.amp"
        install_amp $CATALINA_BASE/webapps/alfresco.war alfresco-rm-$ALF_RM_VER.amp
      ;;
    esac
  fi
  listdodshare="$( java -jar /opt/alfresco/bin/alfresco-mmt.jar list $CATALINA_BASE/webapps/share.war | grep org_alfresco_module_dod5015_share )"
  if [ -z "$listdodshare" -a "$alf_install_share" == "1" ]; then
    echo "Installing Share RM module"
    case "$ALF_DOD_MODULE_URL" in
      *.amp)
        dl_package "$ALF_DOD_SHARE_MODULE_URL" alfresco-dod5015-share.amp
        install_amp $CATALINA_BASE/webapps/share.war alfresco-dod5015-share.amp
        rm alfresco-dod5015-share.amp
      ;;
      *.zip)
        if [ ! -f alfresco-rm-$ALF_RM_VER.zip ]; then dl_package "$ALF_DOD_MODULE_URL" alfresco-rm-$ALF_RM_VER.zip; fi
        if [ ! -f alfresco-rm-share-$ALF_RM_VER.amp ]; then unzip -q alfresco-rm-$ALF_RM_VER.zip "*.amp"; fi
        install_amp $CATALINA_BASE/webapps/share.war alfresco-rm-share-$ALF_RM_VER.amp
        rm alfresco-rm-share-$ALF_RM_VER.amp
      ;;
    esac
  fi
  if [ -f alfresco-rm-$ALF_RM_VER.zip ]; then rm alfresco-rm-$ALF_RM_VER.zip; fi
fi

# Remove web-app folders to force deployment of new apps
rm -rf $CATALINA_BASE/webapps/alfresco
if [ -d $CATALINA_BASE/webapps/share ]; then
  rm -rf $CATALINA_BASE/webapps/share
fi

# Set Tomcat Java defaults
# Use Sun JDK not OpenJDK
# Disable Tomcat security policies
# startup.sh calls catalina.sh, catalina.sh calls setenv *if it exists*
# Let's make it exist!
echo "Configuring Tomcat Catalina variables"
echo "JAVA_HOME=\"$java_home"\" > $CATALINA_BASE/bin/setenv.sh
echo "JAVA_OPTS=\"-Xms128m -Xmx1024m -Xss1024k -XX:MaxPermSize=256m -Dalfresco.home=/opt/alfresco/ -Dcom.sun.management.jmxremote\"" >> $CATALINA_BASE/bin/setenv.sh
echo "TOMCAT6_SECURITY=\"no\"" >> $CATALINA_BASE/bin/setenv.sh

# Enable AJP Connector if it is commented out
ln=`grep -n '\s*<Connector port="8009" protocol="AJP/1.3" redirectPort="8443" />\s*' $CATALINA_BASE/conf/server.xml | cut -d ":" -f 1`
lc="$( wc -l $CATALINA_BASE/conf/server.xml | cut -d " " -f 1 )"
if [[ "`head -n $((ln-1)) $CATALINA_BASE/conf/server.xml | tail -n 1`" == *\<\!--* ]]; then
  if [[ "`head -n $((ln+1)) $CATALINA_BASE/conf/server.xml | tail -n 1`" == *--\>* ]]; then
    head -n $((ln-2)) $CATALINA_BASE/conf/server.xml > $CATALINA_BASE/conf/server.xml.head
    tail -n $((lc-ln-1)) $CATALINA_BASE/conf/server.xml > $CATALINA_BASE/conf/server.xml.tail
    tail -n $((lc-ln+1)) $CATALINA_BASE/conf/server.xml | head -n 1 > $CATALINA_BASE/conf/server.xml.this
    cat $CATALINA_BASE/conf/server.xml.head $CATALINA_BASE/conf/server.xml.this $CATALINA_BASE/conf/server.xml.tail > $CATALINA_BASE/conf/server.xml
    rm $CATALINA_BASE/conf/server.xml.head $CATALINA_BASE/conf/server.xml.this $CATALINA_BASE/conf/server.xml.tail
  fi
fi

# Edit apache configuration
#echo "Configuring Apache HTTPd"
#if [ ! -f /etc/apache2/conf.d/alfresco ]; then
#  cp alfresco-apache2.conf /etc/apache2/conf.d/alfresco
#fi
#if [ -f /etc/apache2/mods-available/proxy.conf ]; then mv /etc/apache2/mods-available/proxy.conf /etc/apache2/mods-enabled/; fi
#if [ -f /etc/apache2/mods-available/proxy_ajp.load ]; then mv /etc/apache2/mods-available/proxy_ajp.load /etc/apache2/mods-enabled/; fi
#if [ -f /etc/apache2/mods-available/proxy.load ]; then mv /etc/apache2/mods-available/proxy.load /etc/apache2/mods-enabled/; fi
#if [ ! -f /var/www/custom-503.html ]; then cp custom-503.html /var/www; fi
#echo "Restarting HTTPd"
#/etc/init.d/apache2 restart

# Tuning
echo "Final system configuration"
# Copy init script which updates IP addresses, etc. - runs on every startup
#cp ec2-init.sh /var/lib/alfresco
#if [ -z "`grep ec2-init.sh /etc/rc.local`" ]; then
#  sed -i.orig 's/^exit 0$/sh \/var\/lib\/alfresco\/ec2-init.sh\nexit 0/' /etc/rc.local 
#fi
# Check the ulimit is set up properly
echo "Setting open file limits"
if [ "`grep \"tomcat6\\s*nofile\" /etc/security/limits.conf`" == "" ]; then
  sed -i.orig 's/^# End of file.*$/alfresco\tsoft\tnofile\t4096\nalfresco\thard\tnofile\t65536\n\n# End of file/' /etc/security/limits.conf
fi

# Import bootstrap data
#if [ -f "share-import-export.zip" -a ! -d "/var/lib/alfresco/bootstrap" ]; then
#  echo "Adding bootstrap data"
#  install_bootstrap_data "share-import-export.zip" "/var/lib/alfresco/bootstrap"
#fi

# Tidy up
echo "Cleaning up"
if [ -d "$ALF_TEMP_DIR" -a $cleanup_after -eq 1 ]; then
  rm -rf $ALF_TEMP_DIR
fi

if [ $alf_network_logged_in -eq 1 ]; then
  alf_network_log_out
fi

echo "Alfresco fully installed."
echo "Please set the LDAP password parameter ldap.synchronization.java.naming.security.credentials in"
echo "/opt/alfresco/tomcat/shared/classes/alfresco-global.properties before starting"
echo "You can start Alfresco by typing: '/etc/init.d/alfresco start' as root"
echo "and stop it by typing '/etc/init.d/alfresco stop' as root too"
exit

# End

# Start Tomcat
#/etc/init.d/tomcat6 start

# Wiping the repo
#rm -rf /var/lib/alfresco/alf_data/
#cat drop-database.sql | mysql -u root -palfresco

