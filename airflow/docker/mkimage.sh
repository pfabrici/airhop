#!/bin/bash

_log() {
	MODULE=$1
	shift
	MSG=$*

	echo `date '+%Y%m%d %t'`": ${MODULE} - ${MSG}"
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
			rm -rf resources/*
		fi

		_log _dlhop "I: get hop"
		wget -O resources/hop.zip ${HOPDLPATH}
		[ $? -ne 0 ] && { EXITCODE=4; break; }

		cd resources
		unzip hop.zip 2>&1 >/dev/null
		[ $? -ne 0 ] && { EXITCODE=6; break; }

		rm -rf hop/config/projects
		cp 

		# cleanup
		rm hop.zip
		[ $? -ne 0 ] && { EXITCODE=8; break; }

		break
	done

	cd $ORIGDIR
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
		_log _mkimg "I: Try to delete image locally"
		docker image rm airflow-custom:${CONTAINERTAG}

		_log _mkimg "I: build container"
		docker build -t airflow-custom:${CONTAINERTAG} .
		[ $? -ne 0 ] && { EXITCODE=8; break; }

		[ ${USE_MINIKUBE} -eq 1 ] && {
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


HOPVERSION=1.1.0
CONTAINERTAG=0.0.6
HOPDLPATH=https://dlcdn.apache.org/hop/${HOPVERSION}/apache-hop-client-${HOPVERSION}.zip
USE_MINIKUBE=1
ECODE=0

while true ; do 
	ORIGDIR=`pwd`

	_dlhop
	[ $? -ne 0 ] && { ECODE=2; break; }

	_mkimg
	[ $? -ne 0 ] && { ECODE=4; break; }

	break
done

case ${ECODE} in
	0) MSG="I: Ok" ;;
	2) MSG="E: download and prep failed" ;;
	4) MSG="E: build failed" ;;
	*) MSG="E: unknown" ;;
esac

cd ${ORIGDIR}
exit ${ECODE}
