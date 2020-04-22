#!/usr/bin/env bash
# ex: set fdm=marker
# usage {{{1 
#/ Usage: 
#/    -h|-?|--help)
#/       show this help and exit
#/
# 1}}} 
# environment {{{1 
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
RUNNING_DIR="$(pwd)"
PROJECT=${PROJECT:-"Some Project Name in $DIR"}
PROJECT_DESCRIPTION=${PROJECT_DESCRIPTION:-"lengthy text about your project"}
# 1}}} 
# functions {{{1 
banner() { # {{{2
  if [ -x "$("command -v figlet")" ] && [ -x "$("command -v cowsay")" ]; then
    BANNER=$(figlet "$PROJECT" | cowsay)
  elif [ -x "$("command -v figlet")" ]; then
    BANNER=$(figlet "$PROJECT")
  elif [ -x "$("command -v cowsay")" ]; then
    BANNER=$(cowsay "$PROJECT")
  else
    BANNER="\\e[34$PROJECT\\e[39m"
  fi
  BANNER="$BANNER\n\\e[33m $PROJECT_DESCRIPTION\\e[39m"
  echo -e "$BANNER"
} # 2}}} 
die() { # {{{2 
  echo -e "\\e[31mFAILURE:\\e[39m $1"
  exit 1
} # 2}}} 
warn() { # {{{2 
  echo -e "\\e[33mWARNING:\\e[39m $1"
} # 2}}} 
info() { # {{{2
  echo -e "\\e[36mINFO: \\e[39m $1"
} # 2}}}
show_help() { # {{{2 
  grep '^#/' "${BASH_SOURCE[0]}" | cut -c4- || \
    die "Failed to display usage information"
} # 2}}} 
# 1}}} 
# arguments {{{1 
while :; do
  case $1 in # check arguments {{{2 
    -h|-\?|--help) # help {{{3 
      banner
      show_help
      exit
      ;; # 3}}} 
    -?*) # unknown argument {{{3 
      warn "Unknown option (ignored): $1"
      shift
      ;; # 3}}} 
    *) # default {{{3 
      break # 3}}} 
  esac # 2}}} 
done
# 1}}} 
# logic {{{1 
banner
if [ "$RUNNING_DIR" == "$DIR" ]; then
  info "Running in source directory:\\e[36m$DIR\\e[39m"
else
  info -e "Running in directory:\n\t\\e[35m$RUNNING_DIR\\e[39m"
fi
# 1}}} 
