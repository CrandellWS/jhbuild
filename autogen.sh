#! /bin/sh
#
# JHBuild configuration script.
#
# For installation instructions please refer to the JHBuild manual:
#   gnome-help ghelp:/jhbuild-source-dir/doc/C/jhbuild.xml
# where 'jhbuild-source-dir' is the full path to the JHBuild source directory.
#
# Or refer to the on-line JHBuild manual at:
#
#  http://library.gnome.org/devel/jhbuild/stable/getting-started.html.en
#
# Usage:
# ./autogen.sh [OPTION]
#    Available OPTION are:
#      --simple-install   Configure without using autotools. This setting is
#                         set automatically if gnome-common and gnome-doc-utils
#                         are not installed.
#      --prefix=PREFIX    Install JHBuild to PREFIX. Defaults to ~/.local
#
# If gnome-common and gnome-doc-utils are available, this configuration script
# will configure JHBuild to install via autotools.
#
# If gnome-common and gnome-doc-utils are not available, this configuration
# script will configure JHBuild to install via a plain Makefile.
#
# autogen.sh is used to configure JHBuild because the most common way to obtain
# JHBuild is via git and a 'configure' should not be checked into git.
#
# autogen.sh supports i18n using the package gettext. If gettext is not
# available english is used. To enable i18n autogen.sh builds mo files from po
# files using po/Makefile.plain. The mo files are in $srcdir/mo.

PKG_NAME=jhbuild

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

setup_i18n()
{
  # Check msgfmt (from gettext) is installed to provide i18n for this script
  hash msgfmt 2>&-
  msgfmtl_available=$?

  # Build mo from po files so i18n works for this script. mo files can't be
  # checked in to git so they must be built here.
  if [ $msgfmtl_available -eq 0 ]; then
    # -s is for silent
    # -C is for change directory
    make -s -C $srcdir/po -f Makefile.plain
  fi

  # Check gettext.sh is installed to provide i18n for this script
  hash gettext.sh 2>&-
  gettext_sh_available=$?

  if [ $gettext_sh_available -eq 0 ]; then
    export TEXTDOMAINDIR=$srcdir/mo
    export TEXTDOMAIN=jhbuild

    . gettext.sh
  fi

  # Check gettext is installed to provide i18n for this script
  hash gettext 2>&-
  gettext_available=$?
}

# parse_commandline parses the commandline and sets shell variables accordingly.
# - sets $enable_autotools if --simple-install specified.
# - sets shell variables from long form options. e.g if commandline contains
#   '--prefix=/opt' then shell variable prefix is set to '/opt'. Shell variable
#   names must start with a letter or underscore and not contain special
#   characters. Invalid variable names are ignored.
# parse_commandline is not using getopt as getopt doesn't support the long form
# on Solaris, BSD and MacOS.
parse_commandline()
{
  enable_autotools=1

  while [ -n "$1" ]; do
    # substring operations available in all sh?
    if [ ${1:0:2} = "--" ]; then
      keyvalue=${1:2}
      key=${keyvalue%%=*}
      value=${keyvalue##*=}
      if [ "$key" = "simple-install" ]; then
        enable_autotools=0
      fi
      echo $key | grep -E '^[A-Za-z_][A-Za-z_0-9]*$' > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        eval $key=$value
      fi
    fi
    shift
  done
}

# configure JHBuild to build and install without autotools via a plain
# Makefile. Sets up a Makefile.inc and copies Makefile.plain to Makefile
configure_without_autotools()
{
  eval_gettext "Configuring \$PKG_NAME without autotools"; echo

  # setup the defaults. The following can changed from the commandline.
  # e.g. ./autogen.sh --prefix=${HOME}/jhbuildhome
  [ -z $prefix ] && prefix=${HOME}/.local
  [ -z $bindir ] && bindir=${prefix}/bin
  [ -z $datarootdir ] && datarootdir=${prefix}/share
  [ -z $desktopdir ] && desktopdir=${datarootdir}/applications

  # Check to see if $srcdir/Makefile.inc is writable
  if [ -f $srcdir/Makefile.inc ]; then
    if [ ! -w $srcdir/Makefile.inc ]; then
      eval_gettext  "Unable to create file \$srcdir/Makefile.inc"; echo
      exit 1
    fi
  else
    if [ ! -w $srcdir ]; then
      eval_gettext  "Unable to create file \$srcdir/Makefile.inc"; echo
      exit 1
    fi
  fi

  echo "# This file is automatically generated by JHBuild's autogen.sh" \
    > $srcdir/Makefile.inc
  echo "# Do NOT edit. This file will be overwritten when autogen.sh is next" \
       "run." >> $srcdir/Makefile.inc
  echo "prefix=$prefix" >> $srcdir/Makefile.inc
  echo "bindir=$bindir" >> $srcdir/Makefile.inc
  echo "datarootdir=$datarootdir" >> $srcdir/Makefile.inc
  echo "desktopdir=$desktopdir" >> $srcdir/Makefile.inc

  if [ ! -f $srcdir/Makefile.plain ]; then
    eval_gettext "Unable to read file $srcdir/Makefile.plain"; echo
    exit 1
  fi

  cp $srcdir/Makefile.plain $srcdir/Makefile || {
    eval_gettext "Unable to copy \$srcdir/Makefile.plain to \$srcdir/Makefile"
    echo
    exit 1
  }

  eval_gettext "Now type \`make' to compile \$PKG_NAME"; echo
}

# configure JHBuild to build and install via autotools.
configure_with_autotools()
{
  export PKG_NAME
  REQUIRED_AUTOCONF_VERSION=2.57 \
  REQUIRED_AUTOMAKE_VERSION=1.8 \
  REQUIRED_INTLTOOL_VERSION=0.35.0 \
  REQUIRED_PKG_CONFIG_VERSION=0.16.0 \
  USE_COMMON_DOC_BUILD=yes gnome-autogen.sh $@
  if [ $? -ne 0 ]; then
    configure_without_autotools
  fi
}

setup_i18n
if [ $gettext_available -ne 0 ]; then
  # If gettext is not installed fallback to echo in english
  gettext() { echo -n $1; }
  # eval_gettext substitutes variables of the form: \$var
  eval_gettext()
  {
    escaped_string=${1/\'/\\\'}
    eval echo -n ${escaped_string/\`/\\\`}
  }
fi

if [ ! -f $srcdir/jhbuild/main.py ]; then
  eval_gettext "**Error**: Directory \`\$srcdir' does not look like the top-level \$PKG_NAME directory"
  echo
  exit 1
fi

# Check gnome-common package is installed. gnome-common depends on autoconf,
# automake and pkgconfig so no need to check them explicitly.
hash gnome-autogen.sh 2>&-
gnome_autogen_available=$?

# Check gnome-doc-tool package is installed.
hash gnome-doc-tool 2>&-
gnome_doc_tool_available=$?

parse_commandline $*

if [ $gnome_autogen_available -eq 0 -a \
     $gnome_doc_tool_available -eq 0 -a \
     $enable_autotools -eq 1 ]; then
  configure_with_autotools $*
else
  if [ $gnome_autogen_available -ne 0 ]; then
    gettext "gnome-autogen.sh not available"; echo
  fi
  if [ $gnome_doc_tool_available -ne 0 ]; then
    gettext "gnome-doc-tools not available"; echo
  fi
  configure_without_autotools
fi
