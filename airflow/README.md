# Airflow on local Kubernetes

In diesem Verzeichnis des Repos wird die Installation von Airflow in einem lokalen Kubernetes Cluster beschrieben. Die Konfiguration beinhaltet die Verwendung des KubernetesExecutors, d.h. die Airflow Worker werden jeweils in einem temporären POD ausgeführt.

Die DAG Definitionen werden aus git in die Pods per git-sync synchronisiert.

Es wird ein custom Airflow Container verwendet. Damit ist es zum einen möglich, weitere Python Bibliotheken einzubinden. Zum anderen soll die Verwendung von Apache Hop auf den Worker Nodes getestet werden. 

## Konfiguration und Installation von Airflow in Kubernetes
Die Konfiguration von Airflow geschieht über eine ```values.yml``` Datei, die alle relevanten Umgebungsvariablen für Helm beinhaltet. Relevante Variablen sind :
* logs->persistence->enabled = true
* dags->persistence->enabled = true
* git_sync ff.
* images

Installiert und gestartet wird mit :
```
helm upgrade --install airflow apache-airflow/airflow -n airflow -f values.yaml --debug
```

## Handling der Custom Containers 

Die Definition des Custom Containers steckt im ```airflow``` Verzeichnis. Die Dateien 
* Dockerfile ( Containerdefinition )
* requirements.txt ( Python Abhängigkeiten )
sind wichtig und müssen zunächst entsprechend angepasst werden.

Wenn ein neuer Custom Container erzeugt werden soll, geschieht das erstmal lokal. Dann wir der Container wie folgt in den Minikube Cluster hochgeladen :
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
defaultAirflowTag: "1.0.0"
airflowVersion: "2.2.2"
```
Abschliessend wird Airflow über helm neu gestartet :
```
helm upgrade --install airflow apache-airflow/airflow -n airflow -f values.yaml --debug
```


## Links

https://airflow.apache.org/docs/helm-chart/stable/manage-dags-files.html
https://www.youtube.com/watch?v=39k2Sz9jZ2c
