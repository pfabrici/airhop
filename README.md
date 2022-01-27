# Apache Airflow und Apache Hop auf Kubernetes mit KubernetesExecutor

Dieses Repo enthält eine Beispielkonfiguration für die kombinierte Installation von Apache Airflow und Apache Hop in einem Kubernetes Cluster. Für die Ausführung von DAGs wird der KubernetesExecutor verwendet, so dass bei jeder Ausführung ein temporärer POD angelegt wird. Die Installation ist so gestaltet, dass man aus einem DAG z.B. per PythonOperator eine HOP Pipeline oder Workflow ausführen kann. 

Als Basis für die Installation wird das offizielle Airflow Helmchart verwendet. Apache Hop wird als zip File von https://hop.apache.org heruntergeladen.

Die DAG Definitionen und HOP Objekte werden aus git in die Pods per git-sync synchronisiert.

## Vorbedingungen
Es wird davon ausgegangen, dass ein kubernetes Cluster konfiguriert und per kubectl bedienbar ist. Wenn dieser nicht vorhanden ist, kann er z.B. mit minikube schnell aufgesetzt werden. Docker muss vorhanden sein, ebenso der Kubernetes Paketmanager helm. Um DAGs und Hop Objekte zur erzeugen ist git und python hilfreich.

Diese Anleitung ist auf einem Ubuntu 20.4 System entstanden.

## Konfiguration und Installation von Airflow in Kubernetes
### Helm vorbereiten
Zunächst wird das Helm Repo hinzugefügt :
```
helm repo add apache-airflow https://airflow.apache.org
```

### Vorbereitung auf dem Kubernetes Cluster 

Für die spätere Abholung der DAGs ( und evtl. Apache HOP Sourcen ) von einem GIT Server benötigen wir ein SSH Schlüsselpaar als Deploykey. Diesen kann man sich einfach mit 
```
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```
generieren. Als Namen für die Schlüsseldateien verwenden wir airflow_dags_rsa. Es wird zudem eine custom configmap und ein eigenes Namespace fürr Airflow verwendet. Wenn noch nicht vorhanden, müssen diese im Kubernetes Cluster angelegt werden. Dabei können wir auch gleich den SSH Key als Secret speichern :

```
kubectl create namespace airflow
kubectl create configmap airflow-variables -n airflow --from-file variables.yaml
kubectl create secret generic airflow-ssh-git-secret --from-file=gitSshKey=airflow_dags_rsa -n airflow
```
Der Public Part des SSH Keys muss dann noch an geeigneter Stelle im GIT Server  ( github/gitea/gogs... ) abgelegt werden, damit später der git-sync funktioniert.

### Vorbereitungen Helm/Airflow Konfiguration

Die Konfiguration von Airflow geschieht über eine ```values.yml``` Datei, die alle relevanten Umgebungsvariablen für Helm beinhaltet. Die Vorlage für die in diesem Repo enthaltenen values.yml kommt aus dem offiziellen Airflow helmchart Repo. 

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
## Apache Hop in Apache Airflow
Apache Hop wird mit in den Apache Airflow Container integriert. Das erlaubt eine einfache Ausführung der Hop Pipelines und Workflows aus den DAGs heraus. Dazu werden im Dockerfile die entsprechenden Verzeichnisse angelegt und die Dateien kopiert. Apache Hop bekommt einen eigenen ```hop``` User, der der Gruppe ```apache``` angehört. Dem airflow Benutzer des Containers fügen wir ebenfalls die Gruppe apache hinzu, so das wir über die Gruppe übergreifende Rechte erteilen können.  

## Links

* https://k8s-docs.netlify.app/en/docs/tasks/tools/install-minikube/
* https://airflow.apache.org/docs/helm-chart/stable/index.html
* https://airflow.apache.org/docs/helm-chart/stable/manage-dags-files.html
* https://www.youtube.com/watch?v=39k2Sz9jZ2c
* https://phoenixnap.com/kb/install-minikube-on-ubuntu
