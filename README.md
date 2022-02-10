# Apache Airflow und Apache Hop auf Kubernetes mit KubernetesExecutor

Dieses Repo enthält eine Beispielkonfiguration für die Verwendung von Apache Airflow als Scheduler von Apache Hop in einem Kubernetes Cluster. Für die Ausführung der Hop-DAGs wird der KubernetesExecutor verwendet, so dass bei jeder Ausführung ein temporärer POD angelegt wird, der die Hop Workflows und Pipelines ausführt. 
Die Apache Hop Installation wird in diesem Setup in den Airflow Worker Container integriert.
Hop wird aus den DAGs über einen PythonOperator und einem Python SubProcess gestartet.
Sowohl die Airflow DAG Scripts als auch die HOP Objekte werden beim Start eines PODs aus git per git-sync abgeholt.

Als Basis für dieses Setup wird das offizielle Airflow Helmchart verwendet. Für die Ergänzung des Airflow Worker Containers verwende ich das Apache Hop Package, welches über die Downloadseite herunterladbar ist.

## Vorbedingungen
Dieses Setup ist auf einem Ubuntu 20.4 System entstanden.

Es wird davon ausgegangen, dass ein Kubernetes Cluster konfiguriert und von der Kommandozeile per kubectl bedienbar ist. Wenn dieser nicht vorhanden ist, kann er z.B. mit minikube schnell aufgesetzt werden. Docker muss vorhanden sein, ebenso der Kubernetes Paketmanager helm. Um DAGs und Hop Objekte zur erzeugen ist git und python hilfreich.

* Installation von Docker : https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04
* Minikube : https://kubernetes.io/de/docs/tasks/tools/install-minikube/
* Installation von Helm : https://helm.sh/docs/intro/install/
* Installation von git, python : Paketmanager "sudo apt-get install git python3"

Der für dieses Setup verwendete Linux Benutzer sollte in der docker gruppe enthalten sein :
```
sudo usermod -a -G docker <user>
```

Anschliessend wird das hier beschriebene Repository kub4us gecloned :
```
git clone git@sources.zeith.net:peter.fabricius/kub4us.git
```
Das Repository verfügt über zwei Unterverzeichniss : 
* airflow enthält alle Scripte/Konfigurationen, die zur Installation der Software im Cluster notwendig sind sowie die Sourcen für den  
* sources enthält Beispiel DAGs und Hop Sourcen, die später in den Worker gesynct werden

Die weiteren Schritte finden im Verzeichnis ```airflow``` statt.
```
cd kub4us/airflow
```

## Konfiguration und Installation von Airflow in Kubernetes
### Helm vorbereiten
Zunächst wird das Helm Repo hinzugefügt, aus dem dann Airflow in Kubernetes installiert wird.
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

Die Konfiguration von Airflow geschieht über eine ```values.yml``` Datei, die alle relevanten Umgebungsvariablen für Helm beinhaltet. Die Vorlage für die in diesem Repo enthaltenen ```values.yml``` kommt aus dem offiziellen Airflow helmchart Repo und ist an unsere Bedürfnisse angepasst worden.

In der ```values.yml``` wird ein fernet Key angegeben. Dieser dient der Verschlüsselung von Passwörtern in der Variablenverwaltung von Airflow. Eine Anleitung zum Erstellen des Keys gibt es unter https://airflow.apache.org/docs/apache-airflow/stable/security/secrets/fernet.html#security-fernet . Der fernetSecretKeyName ist auf fernetsecret gesetzt ( muss komplett lowercase sein ).

### Handling der Custom Containers für die Airflow Worker

Anstelle des Airflow Images vom docker Hub soll ein eigenes Image verwendet werden, welches Apache Hop enthält. Neben der Hop Installation soll weiterhin die Integration von weiteren Python Modulen in das Image über Angabe der Module in einer ```requirements.txt```Datei möglich sein. Die Definition des Custom Containers steckt im ```airflow/docker``` Verzeichnis in Form einer Dockerfile Containerdefinition.
Mit dem dort verfügbaren Utility ```mkimage.sh``` können einfach neue Versionen des Images erzeugt werden.

Wird das Tag oder die Airflow Version im Image verändert, müssen zusätzlich in der ```values.xml``` Anpassungen bei den entsprechenden Parametern gemacht werden :
```
defaultAirflowRepository: airflow-custom
defaultAirflowTag: "${TAG}"
airflowVersion: "2.2.2"
```

### Airflow via Helm installieren oder aktualisieren

Installiert, Upgedated und ge-/restartet wird dann mit :
```
helm upgrade --install airflow apache-airflow/airflow -n airflow -f values.yaml --debug
```

## Airflow WebUI
Um die Airflow WebUI zugänglich zu machen muss ein Port-Forward eingerichtet werden :
```
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace airflow
```
Das geht erst, wenn das Helm Chart vollständig installiert ist und läuft. Das kann mit 
```
kubectl get po -n airflow
```
geprüft werden.

## Apache Hop in Apache Airflow
Apache Hop ist nun in den Apache Airflow Container integriert und es können damit DAGs implementiert werden, die Hop Objekte ausführen. DAG Skripte und Hop Sourcen werden zur Laufzeit des PODs über git-sync in den Container geholt. In dem hier beschriebenem Repository finden sich DAG und Hop Sourcen im Verzeichnis ```sources/dag``` bzw. ```sources/hop```. In der ```airflow/values.xml``` wird git-sync so konfiguriert, dass das ```sources``` Verzeichnis aus dem Repo direkt in den Container gesynct wird.

In der Hop Konfiguration innerhalb des Containers ist zudem sichergestellt, dass das notwendige Hop "Default"-Projekt auf das gesyncte ```sources/hop``` verweist. Zu beachten ist, dass die gesyncten Dateien in einem Read-Only Verzeichnis liegen. Dadurch können z.B. keine Metadatenobjekte durch Hop an die Defaultlocations geschrieben werden.

Unter ```sources/hop``` sind einige Dateien und Verzeichnisse deswegen zwingend notwendig:
* project-config.json 
* metadata mit einigen Unterverzeichnissen und den run-configurations
* die pipeline-log/-probe workflow-log Verzeichnisse müssen angelegt sein, da Hop beim Start eines Jobs abbricht, wenn sie nicht anlegbar sind



## Links

* https://k8s-docs.netlify.app/en/docs/tasks/tools/install-minikube/
* https://airflow.apache.org/docs/helm-chart/stable/index.html
* https://airflow.apache.org/docs/helm-chart/stable/manage-dags-files.html
* https://www.youtube.com/watch?v=39k2Sz9jZ2c
* https://phoenixnap.com/kb/install-minikube-on-ubuntu
