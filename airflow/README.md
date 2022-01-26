# Airflow on local Kubernetes

Installation einer Airflow Installation auf einem lokalen
Kubernetes Cluster. Verwendung des Kubernetes Executors,
d.h. die Tasks der DAGs werden auf short-lived Pods ausgeführt.

Die DAG Definitionen werden regelmäßig aus git in die Pods synchronisiert.

Es wird ein custom Airflow Container verwendet, der es erlaubt eigene
Provider / Module zu verwenden.

## Umgang mit dem Custom Containers 

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
