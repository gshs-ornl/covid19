#!/usr/bin/env bash
# usage {{{1 ------------------------------------------------------------------
#/ Usage: 
#/        ./dev.sh [OPTIONS]
#/    
#/   -h|-?|--help)
#/       show this help and exit
#/
#/   -b|--build-base)
#/       build the base image
#/
#/   -p|--push)
#/       push the base image
#/
#/   -t|--tag
#/       the tag for the image without the label
#/
#/   -l|--label)
#/       specify label for image
#/
#/   -u|--up)
#/       spin up the docker stack
#/
#/   -P|--pull)
#/       get the latest base image
#/
#/   -i|--interactive)
#/       enter specified container interactively
#/
# 1}}} ------------------------------------------------------------------------
# environment {{{1 ------------------------------------------------------------
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BASE="$( basename "$DIR")"
TAG="code.ornl.gov:4567/nset_covid19/covid19scrapers/base"
LABEL="latest"
BUILD=0
PUSH=0
UP=0
INTERACTIVE=0
DE=0
RETRIEVE=0
# 1}}} ------------------------------------------------------------------------
# functions {{{1 --------------------------------------------------------------
banner() { # {{{2 -------------------------------------------------------------
  echo -e "\\e[35m"
  cat << EOF
                _     _ _
  ___ _____   _(_) __| | |__  
 / __/ _ \\ \\ / / |\/ _\` | '_ \ 
| (_| (_) \\ V /| | (_| | |_) |
 \\___\\___/ \\_/ |_|\\__,_|_.__/    devtools

EOF
  echo -e "\\e[39m"
                              
} # 2}}} ----------------------------------------------------------------------
die() { # {{{2 ----------------------------------------------------------------
  echo -e "\\e[31mFAILURE:\\e[39m $1"
  exit 1
} # 2}}} ----------------------------------------------------------------------
info() { # {{{2
  echo -e "\\e[36mINFO:\\e[39m $1"
} # 2}}}
warn() { # {{{2 ---------------------------------------------------------------
  echo -e "\\e[33mWARNING:\\e[39m $1"
} # 2}}} ----------------------------------------------------------------------
show_help() { # {{{2 ----------------------------------------------------------
  grep '^#/' "${BASH_SOURCE[0]}" | cut -c4- || \
    die "Failed to display usage information"
} # 2}}} ----------------------------------------------------------------------
# 1}}} ------------------------------------------------------------------------
# arguments {{{1 --------------------------------------------------------------
while :; do
  case $1 in # check arguments {{{2 -------------------------------------------
    -b|--build-base) # {{{3
      BUILD=1
      shift
      ;; # 3}}}
    -p|--push) # {{{3
      PUSH=1
      shift
      ;; # 3}}}
    -i|--interactive) # {{{3
      UP=1
      INTERACTIVE=1
      DE="$2"
      shift
      ;; # 3}}}
    -t|--tag) # {{{3
      TAG=$2
      shift 2
      ;; # 3}}}
    -l|--label) # {{{3
      LABEL=$2
      shift 2
      ;; # 3}}}
    -u|--up) # {{{3
      UP=1
      shift
      ;; # 3}}}
    -P|--pull) # {{{3
      RETRIEVE=1
      shift
      ;; # 3}}}
    -h|-\?|--help) # help {{{3 ------------------------------------------------
      banner
      show_help
      exit
      ;; # 3}}} ---------------------------------------------------------------
    -?*) # unknown argument {{{3 ----------------------------------------------
      warn "Unknown option (ignored): $1"
      shift
      ;; # 3}}} ---------------------------------------------------------------
    *) # default {{{3 ---------------------------------------------------------
      break # 3}}} ------------------------------------------------------------
  esac # 2}}} -----------------------------------------------------------------
done
# 1}}} ------------------------------------------------------------------------
# logic {{{1 ------------------------------------------------------------------
banner
IMAGE_TAG="$TAG:$LABEL"
if [ "$RETRIEVE" -eq "1" ]; then
  info "Pulling latest image $IMAGE_TAG"
  docker pull "$IMAGE_TAG"
fi
if [ "$BUILD" -eq "1" ]; then
  info "Building image $IMAGE_TAG"
  docker build -t "$IMAGE_TAG" -f base/Dockerfile base/
fi
if [ "$PUSH" -eq "1" ]; then
  info "Pushing image $IMAGE_TAG"
  docker push "$IMAGE_TAG"
fi
if [ "$UP" -eq "1" ]; then
  info "Spinning up stack"
  docker-compose up -d --build scraper tidy db api
fi
if [ "$INTERACTIVE" -eq "1" ]; then
  info "Dropping into shell of $DE"
  docker exec -it "${BASE}_${DE}_1" bash
fi
# 1}}} ------------------------------------------------------------------------
