#!/bin/bash

_usage() {
	echo "och"
	exit 5
}

_init() {
	kubectl create namespace ${NAMESPACE}
}

_up() {
	kubectl apply -f jenkins-pv.yml -n ${NAMESPACE}
	kubectl apply -f jenkins-pvc.yml -n ${NAMESPACE}
	kubectl apply -f jenkins-deployment.yml -n ${NAMESPACE}
	kubectl apply -f jenkins-service.yml -n ${NAMESPACE}

	nohup kubectl port-forward -n jenkins service/jenkins 8080 &
	echo $! >  ${LOCKFILE}
}


_down() {
	PID=`cat ${LOCKFILE}`
	kill $PID

	kubectl delete -f jenkins-service.yml -n ${NAMESPACE}
	kubectl delete -f jenkins-deployment.yml -n ${NAMESPACE}
	kubectl delete -f jenkins-pvc.yml -n ${NAMESPACE}
	kubectl delete -f jenkins-pv.yml -n ${NAMESPACE}
}

NAMESPACE=jenkins
LOCKFILE=jenkins.lck

[ $# -lt 1 ] && _usage
CMD=$1


case ${CMD} in 
	up)	_up ;;
	down)	_down ;;
	*)	_usage ;;
esac
