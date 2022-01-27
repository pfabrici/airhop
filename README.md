# Airflow on local Kubernetes

In diesem Verzeichnis des Repos wird die Installation von Airflow in einem lokalen Kubernetes Cluster beschrieben. Die Konfiguration beinhaltet die Verwendung des KubernetesExecutors, d.h. die Airflow Worker werden jeweils in einem temporären POD ausgeführt.

Die DAG Definitionen werden aus git in die Pods per git-sync synchronisiert.

Es wird ein custom Airflow Container verwendet. Damit ist es zum einen möglich, weitere Python Bibliotheken einzubinden. Zum anderen soll die Verwendung von Apache Hop auf den Worker Nodes getestet werden. 


## Konfiguration und Installation von Airflow in Kubernetes
### Vorbereitung auf dem Kubernetes Cluster 

Ich verwende eine custom configmap und ein eigenes Namespace fuer airflow. Wenn noch nicht vorhanden, muessen diese angelegt werden :

```
kubectl create namespace airflow
kubectl create configmap airflow-variables -n airflow --from-file variables.yaml
kubectl create secret generic airflow-ssh-git-secret --from-file=gitSshKey=airflow_dags_rsa -n airflow
```

### Vorbereitungen Helm/Airflow Konfiguration

Die Konfiguration von Airflow geschieht über eine ```values.yml``` Datei, die alle relevanten Umgebungsvariablen für Helm beinhaltet. Relevante Variablen sind :
* logs->persistence->enabled = true
* dags->persistence->enabled = true
* git_sync ff.
* images



### Handling der Custom Containers 

Anstelle des Airflow Images vom docker Hub verwende ich ein selbst erstelltes. Damit soll es möglich sein, weitere Python Bibliotheken und andere ETL Komponenten in das Image zu integrieren und in den DAGs verfügbar zu machen. Die Definition des Custom Containers steckt im ```airflow``` Verzeichnis in Form einer Dockerfile Containerdefinition. Die Dateien 
* Dockerfile ( Containerdefinition )
* requirements.txt ( Python Abhängigkeiten )
* und das Verzeichnis resources
sind dafür relevant und müssen zunächst entsprechend angepasst werden. Aus dem Dockerfile wird dann mit ```docker build -t airflow-custom:${TAG} .``` ein Image gebaut.
Dann wir das Image wie folgt in den Minikube Cluster hochgeladen :
```
cd airflow
TAG="1.0.0"
docker image rm airflow-custom:${TAG}
docker build -t airflow-custom:${TAG} .
minikune image rm airflow-custom:${TAG}
minikube image load airflow-custom:${TAG}
```
Wird das Tag oder die Airflow Version verändert, müssen zusätzlich in der values.xml Anpassungen bei den entsprechenden Parametern gemacht werden :
```
defaultAirflowRepository: airflow-custom
defaultAirflowTag: "${TAG}"
airflowVersion: "2.2.2"
```

### Airflow via Helm aktualisieren

Installiert, Upgedated und ge-/restartet wird dann mit :
```
helm upgrade --install airflow apache-airflow/airflow -n airflow -f values.yaml --debug
```

## Airflow WebUI

```
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace airflow
```


## Links

* https://airflow.apache.org/docs/helm-chart/stable/manage-dags-files.html
* https://www.youtube.com/watch?v=39k2Sz9jZ2c
* https://phoenixnap.com/kb/install-minikube-on-ubuntu
