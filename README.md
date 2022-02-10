# Apache Airflow und Apache Hop auf Kubernetes mit KubernetesExecutor

Dieses Repo enthält eine Beispielkonfiguration für die Verwendung von Apache Airflow als Scheduler von Apache Hop in einem Kubernetes Cluster mit Hilfe des KubernetesExecutors. D.h. das für die Ausführung eines jeden DAG ein eigener POD in Kubernetes gestartet wird, der nach Beendigung des Prozesses wieder verschwindet. In den DAGs wird ein PythonOperator verwendet, um Apache Hop zu starten.
Sowohl die Airflow DAG Scripts als auch die HOP Objekte werden beim Start eines PODs aus git per git-sync abgeholt. Es sind keine HOP/DAG Sourcen im Container enthalten.

Als Basis für dieses Setup wird das offizielle Airflow Helmchart verwendet. Für die Ergänzung des Airflow Worker Containers wird beim Build des Images ein Hop Package von der Hop Website heruntergeladen.

## Vorbedingungen
Dieses Setup ist auf einem Ubuntu 20.4 System entstanden.

Es wird davon ausgegangen, dass ein Kubernetes Cluster konfiguriert und von der Kommandozeile per kubectl bedienbar ist. Wenn dieser nicht vorhanden ist, kann er z.B. mit minikube schnell aufgesetzt werden. Docker muss vorhanden sein, ebenso der Kubernetes Paketmanager helm. Um DAGs und Hop Objekte zu ändern ist git und python sowie eine lokale Apache Hop Installation nötig.

* Installation von Docker : https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04
* Minikube : https://kubernetes.io/de/docs/tasks/tools/install-minikube/
* Installation von Helm : https://helm.sh/docs/intro/install/
* Installation von git, python : Paketmanager ```sudo apt-get install git python3```

Der für dieses Setup verwendete Linux Benutzer muss in der docker gruppe enthalten sein, sonst benötigt man hier und da ein sudo mehr :
```
sudo usermod -a -G docker <user>
```

Anschliessend wird das hier beschriebene Repository kub4us gecloned :
```
git clone git@sources.zeith.net:peter.fabricius/kub4us.git
```
Das Repository verfügt über zwei Unterverzeichniss : 
* airflow enthält alle Scripte/Konfigurationen, die zur Installation der Software im Cluster notwendig sind
* sources enthält beispielhafte DAGs und Hop Sourcen, die später in den Worker gesynct werden

Die weiteren Schritte finden im Verzeichnis ```airflow``` statt:
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

Die Airflow Installation soll in einem eigenen Namespace installiert werden. Wenn noch nicht vorhanden, kann er mit 
```
kubectl create namespace airflow
```
angelegt werden. In dem Namespace werden vor Aufruf des Helm-Charts zwei weitere Elemente vorbereitet: 
* das ssh Secret, welches den Deploykey für die Synchronisierung der DAGs/Hop Sourcen aus einem git Repo enthält
* ein Fernet Secret, welches für die Verschlüsselung von Variablen in Airflow benötigt wird
* eine Config Map für die Ablage von Variablen für die DAG Ausführung.

### SSH Secret
Ein ssh Key wird schnell mit  
```
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```
erzeugt. Als Namen für die Schlüsseldateien verwenden wir airflow_dags_rsa, da diese Namen bereits in der ```airflow/values.yml``` im git-sync Abschnitt verwendet werden. Der Key wird dann mit 
```
kubectl create secret generic airflow-ssh-git-secret --from-file=gitSshKey=airflow_dags_rsa -n airflow
```
in den Kubernetes Server geladen. Der Publickey muss als Deploykey im Folgenden noch an geeigneter Stelle im git Server abgelegt werden.

#### Fernet Secret
Das Fernet Secret kann mit 
```
python3 -m venv venv
. venv/bin/activate
pip3 install cryptography
python3 fernet.py > fernet.key
deactivate
``` 
erzeugt und mit 
```
kubectl create secret generic airflow-fernet-secret --from-file=fernet-key=fernet.key -n airflow
```
im Cluster angelegt werden. Auf das Secret wird in der ```airflow/values.yml``` verwiesen, wenn es im Cluster nicht vorhanden ist starte der Server nicht.

### Configmap
Die Configmap basiert auf der Datei ```airflow/variables.yaml``` dieses Repos und wird mit
```
kubectl create configmap airflow-variables -n airflow --from-file variables.yaml
```
angelegt. 


### Vorbereitungen Helm/Airflow Konfiguration

Die Konfiguration von Airflow geschieht über die ```airflow/values.yml``` Datei, die alle relevanten Steuerungsvariablen für den Helm-Chart beinhaltet. Die Vorlage für die in diesem Repo enthaltenen ```airflow/values.yml``` kommt aus dem offiziellen Airflow helmchart Repo und ist hier entsprechend angepasst worden :
* Einrichtung git-sync
* fernet-key
* custom Airflow Image
* ...

### Handling der Custom Containers für die Airflow Worker

Anstelle des Airflow Images vom docker Hub soll ein eigenes Image verwendet werden, welches Apache Hop enthält. Neben der Hop Installation soll weiterhin die Integration von weiteren Python Modulen in das Image über Angabe der Module in einer ```requirements.txt```Datei möglich sein. Die Definition des Custom Containers steckt im ```airflow/docker``` Verzeichnis in Form einer Dockerfile Containerdefinition.
Mit dem dort verfügbaren Utility ```mkimage.sh``` können einfach neue Versionen des Images erzeugt werden.
```
cd docker
mkimage.sh -m
cd ..
```

Wird das Tag oder die Airflow Version im Image verändert, müssen zusätzlich in der ```values.xml``` Anpassungen bei den entsprechenden Parametern gemacht werden :
```
defaultAirflowRepository: airflow-custom
defaultAirflowTag: "${TAG}"
airflowVersion: "2.2.2"
```

### Airflow via Helm installieren oder aktualisieren

Letztendlich muss Airflow im Kubernetes Clusterr installiert werden. Das geht mit folgendem Kommando :
```
helm upgrade --install airflow apache-airflow/airflow -n airflow -f values.yaml --debug
```
Sind Änderungen in der ```values.yml``` erfolgt oder hat sich das custom Image verändert kann das gleiche Kommando für ein Upgrade verwendet werden.

Helm braucht beim ersten Start eine ganze Weile, um die Installation fertigzustellen. Mit 
```
kubectl get po -n airflow 
``` kann man den aktuellen Status einsehen. Wenn alles funktionsbereit ist, sollte die Ausgabe etwa so aussehen :
```
NAME                                 READY   STATUS    RESTARTS   AGE
airflow-postgresql-0                 1/1     Running   0          4m17s
airflow-scheduler-56b8fc88fc-6d84d   3/3     Running   0          4m17s
airflow-statsd-75f567fd86-st744      1/1     Running   0          4m17s
airflow-triggerer-69fd8cd56f-p4nb7   1/1     Running   0          4m17s
airflow-webserver-6c598dd6d6-vx445   1/1     Running   0          4m17s
```

## Airflow WebUI

Um die Airflow WebUI zugänglich zu machen muss ein Port-Forward eingerichtet werden :
```
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace airflow
```
Ist der Port-Forward erfolgreich, kann man mit einem Webbrowser auf die Airflow Installation im Kubernetes Cluster über ```http://127.0.0.1:8080``` zugreifen. Username/Passwort lautet  admin/admin.

## Test der Installation
Wenn alles funktioniert hat, sollten nun zwei DAGs in Airflow sichtbar sein, hello_world und hop. hello_world führt einen simplen Python Operator aus, der einen String ins Logfile druckt. "hop" startet die Hop Pipeline aus ```sources/hop/generated_rows.hpl```.
Während der Ausführung der DAGs kann man per ```kubectl get po -n airflow``` beobachten, wie zusötzliche PODs aufgemacht werden und wieder verschwinden.

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
