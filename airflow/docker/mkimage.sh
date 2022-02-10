#!/bin/bash

_log() {
	MODULE=$1
	shift
	MSG=$*

	echo `date '+%Y%m%d %t'`": ${MODULE} - ${MSG}"
}

_usage() {
	echo "Shellutility ${BASENAME}"
	echo
	echo "Script for generating a Airflow/Hop docker image"
	echo
	echo "Syntax : "
	echo "${BASENAME} [-d] [-m] [-t <ident>] [-h <hopversion>]"
	echo 
	echo "-d : debug / bash set -x"
	echo "-m : upload new image to minikube"
	echo "-t : tag the image e.g. '-t 0.0.2'. Default is 0.0.1"
	echo "-v : Hop version to download e.g. '-v 1.1.0'. Default is 1.1.0"
	echo "     see https://hop.apache.org for available versions"
	echo

	exit 42
}

_parseparams() {
        typeset X

        while getopts dmt:v: X; do
                case $X in
                        d) DEBUG=1 ;;
                        m) USE_MINIKUBE=1 ;;
                        t) CONTAINERTAG="${OPTARG}" ;;
                        v) HOPVERSION=${OPTARG} ;;
                        ?) _usage ;;
                esac
        done

        return $ECODE
}

_dlhop() {
	typeset -i EXITCODE=0
	_log _dlhop "I: Start"

	while true ; do 
		_log _dlhop "I: Prepare folder"
		if [ ! -d resources ] ; then  
			mkdir -p resources
			[ $? -ne 0 ] && { EXITCODE=2; break; }
		else
			rm -rf resources/hop
		fi

		_log _dlhop "I: get hop"
		wget -O resources/hop.zip ${HOPDLPATH}
		[ $? -ne 0 ] && { EXITCODE=4; break; }

		unzip resources/hop.zip -d resources 2>&1 >/dev/null
		[ $? -ne 0 ] && { EXITCODE=6; break; }

		# set the container specific project path
		# by putting a custom hop_config.json in place
		rm -rf resources/hop/config/projects
		cp hop-config.json resources/hop/config

		# copy additional files from hop_custom
		# into the hop target folder
		if [ -d resources/hop_custom ] ; then
			cp -pr resources/hop_custom/* resources/hop
		fi

		# cleanup
		rm resources/hop.zip
		[ $? -ne 0 ] && { EXITCODE=8; break; }

		break
	done

	case ${EXITCODE} in
		0) MSG="I: Ok" ;;
		2) MSG="E: could not created folder" ;;
		4) MSG="E: wget failed" ;;
		6) MSG="E: unzip failed" ;;
		8) MSG="E: cleanup failed" ;;
		*) MSG="E: unknown" ;;
	esac

	_log _dlhop "${MSG}"
	return ${EXITCODE}
}


_mkimg() {
	typeset -i EXITCODE=0
	_log _mkimg "I: Start"

	while true ; do 
		pwd
		_log _mkimg "I: Try to delete image locally"
		docker image rm airflow-custom:${CONTAINERTAG}

		_log _mkimg "I: build container"
		docker build -t airflow-custom:${CONTAINERTAG} .
		[ $? -ne 0 ] && { EXITCODE=8; break; }

		[ ${USE_MINIKUBE} -eq 1 ] && {
			_log _mkimg "I: Upload image to minikube"
			minikube image load airflow-custom:${CONTAINERTAG}
		}

		break
	done

	case ${EXITCODE} in
		0) MSG="I: Ok" ;;
		*) MSG="E: unknown" ;;
	esac

	_log _mkimg "${MSG}"
	return ${EXITCODE}
}

BASENAME=$( basename $0 .ksh )
HOPVERSION=1.1.0
CONTAINERTAG=0.0.1
HOPDLPATH=https://dlcdn.apache.org/hop/${HOPVERSION}/apache-hop-client-${HOPVERSION}.zip
USE_MINIKUBE=0
DEBUG=0
ECODE=0

while true ; do 

	_parseparams $*
	[ $? -ne 0 ] && { ECODE=1; break; }
	[ ${DEBUG:-0} -eq 1 ] && set -x

	_log _main "MSG: Hop:${HOPVERSION} Containertag:${CONTAINERTAG} Minikube:${USE_MINIKUBE}"

	_dlhop
	[ $? -ne 0 ] && { ECODE=2; break; }

	_mkimg
	[ $? -ne 0 ] && { ECODE=4; break; }

	break
done

case ${ECODE} in
	0) MSG="I: Ok" ;;
	1) MSG="E: parseparams failed" ;;
	2) MSG="E: download and prep failed" ;;
	4) MSG="E: build failed" ;;
	*) MSG="E: unknown" ;;
esac

[ ${DEBUG:-0} -eq 1 ] && set +x
exit ${ECODE}
