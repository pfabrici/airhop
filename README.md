# Apache Airflow and Apache Hop on Kubernetes with KubernetesExecutor

Many Data Engineers recognize Apache Airflow as an ELT or data integration tool, but on its website it is declared as "... a platform created by the community to programmatically author, schedule and monitor workflows." Apache Hop is eventually a good extension to Airflow if you do not want to implement your ELT/ETL pipelines in a scripting language but with a graphical rapid development environment.

This repo contains a sample configuration for using Apache Airflow as the scheduler of Apache Hop in a Kubernetes cluster using KubernetesExecutor. That means a separate POD is started in Kubernetes for each execution of a DAG. The PODs are shutdown when the process is finished, so the solution does not use many resources on the cluster. In the DAGs, a PythonOperator in combination with Pythons "subProcess" is used to start Apache Hop processes. With the subprocess approach it is possible to see Apache Hop logs immediatly and in full length.
Both, the Airflow DAG scripts and the HOP objects are fetched by the Airflow worker POD from git via git-sync when a POD is getting started. There are no HOP/DAG sources included in the container, which makes the solution re-usable for different projects.
The official Airflow helm chart is used as the basis for this setup. For the addition of the Airflow Worker container, a hop package is downloaded from the hop website when building the image.

## Prerequisits
This setup was created on an Ubuntu 20.4 system.

It is assumed that a Kubernetes cluster is configured and operable from the command line via kubectl. If this is not present, it can be set up quickly with minikube, for example. The docker cli needs to be present, as well as the Kubernetes package manager helm. To change DAGs and Hop objects, git and python are required, as well as a local Apache Hop installation.

* Installation of Docker : https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04
* Minikube : https://kubernetes.io/de/docs/tasks/tools/install-minikube/
* Installation of Helm : https://helm.sh/docs/intro/install/
* Installation of git, python : use the OS package manager, e.g. ```sudo apt-get install git python3```

The Linux user used for this setup should be included in the docker group to ease further steps
```
sudo usermod -a -G docker <user>
```

As you need a git repository with your own deploy key to run the git-sync mechanism later on it is necessary to clone this repository within git to a user you can administer. After forking you can clone your repository to a place on your computer :
```
git clone git@sources.zeith.net:peter.fabricius/airhop.git
```
The repository has two subdirectories :
* airflow contains all scripts/configurations necessary to install the software in the cluster.
* sources contains sample DAGs and hop sources that will later be synced into the worker.

The following steps take place in the ``airflow`` directory:
```
cd airhop/airflow
```

## Configuration and installation of Airflow in Kubernetes
### Prepare Helm 
First, the Helm repo is added, from which Apache Airflow is then installed into Kubernetes.
```
helm repo add apache-airflow https://airflow.apache.org
```

### Preparations on the Kubernetes Cluster
The Apche Airflow installation should be installed in its own namespace. If it does not already exist, it can be created with
```
kubectl create namespace airflow
```
Three additional elements are prepared in the namespace before calling the Helm chart:
* the ssh secret, which contains the deploykey for synchronizing DAGs/Hop sources from a git repo.
* a fernet secret, which is needed for encrypting variables in Airflow
* a config map for storing variables for DAG execution.

### SSH Secret
A ssh key pair can easily be created with 
```
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```
We use ```airflow_dags_rsa``` as the names for the key files, since these names are already used in the ``airflow/values.yml`` in the git-sync section. The secret gets uploaded into Kubernetes by 

```
kubectl create secret generic airflow-ssh-git-secret --from-file=gitSshKey=airflow_dags_rsa -n airflow
```
The Publickey must then be stored as deploykey in the git repository where the DAG/Hop sources are stored.

#### Fernet Secret
Airflow uses a fernet key to crypt variables in its own variable store. We have to create an installation specific key.  The fernet key can be generated with a simple python script. Create a python virtual environment to install the cryptography module locally before you run the generation script :
```
python3 -m venv venv
. venv/bin/activate
pip3 install cryptography
python3 fernet.py > fernet.key
deactivate
``` 
Upload the resulting key file to  Kubernetes by running
```
kubectl create secret generic airflow-fernet-secret --from-file=fernet-key=fernet.key -n airflow
```
The secret will be referenced in ```airflow/values.yml```. When the secret is not available in the Kubernetes namespace Airflow will not come up.

### Configmap
We use a Kubernetes ConfigMap to pass an Apache Hop variable environment into the Airflow Worker nodes. An example ConfigMap with some basic variables are prepared in ```airflow/variables.yaml``` of this repository. All variables declared in the ConfigMap will later be available in the HOP pipelines and workflows. You can upload the ConfigMap to K8S by running 
```
kubectl create configmap airflow-variables -n airflow --from-file variables.yaml
```

### Preparation of the Helm/Airflow configuration
The configuration of Airflow is done in the ``airflow/values.yml`` file, which contains all relevant control variables for the helm chart. The template for the ``airflow/values.yml`` included in this repo comes from the official airflow helmchart repo and has been adapted here accordingly. It now contains specific
* a reference to the fernet secret
* configuration of the custom worker image
* configuration of a volume that mounts the ConfigMap into the worker
* git-sync setup incl. git ssh key

To make git-sync work with your own repository where you set your own deploy key you have to exchange the repo line in ```airflow/values.yml``` accordingly :

```
 gitSync:
    enabled: true
    repo: ssh://git@github.com:pfabrici/airhop.git
```


### Managing the custom worker image including the Apache Hop installation
Instead of the Airflow image from docker Hub, a separate image is to be used that contains Apache Hop. In addition to the Hop installation, it should also be possible to integrate other Python modules into the image by specifying the modules in a ``requirements.txt`` file. The definition of the custom container is located in the ``airflow/docker`` directory in the form of a Dockerfile container definition.
The ``mkimage.sh`` utility available there can be used to easily create new versions of the image.

```
cd docker
mkimage.sh -m
cd ..
```
If ``mkimage.sh`` finds a directory ```airflow/docker/resources/hop-custom``, its entire contents will be copied 1:1 to the hop directory in the image. This can be used to add e.g. JDBC drivers or additional plugins.

If the tag or the airflow version is changed in the image, additional adjustments must be made to the corresponding parameters in the ``values.xml``:

```
defaultAirflowRepository: airflow-custom
defaultAirflowTag: "${TAG}"
airflowVersion: "2.2.2"
```

### Install Airflow !

Finally, Airflow needs to be installed in the Kubernetes clusterr. This can be done with the following command :

```
helm upgrade --install airflow apache-airflow/airflow -n airflow -f values.yaml --debug
```
If changes have been made to the ``values.yml`` or the custom image has changed, the same command can be used for an upgrade.
Helm takes quite a while to complete the installation when first launched. With
```
kubectl get po -n airflow 
``` 
you can see the current status. When everything is functional, the output should look something like this :
```
NAME                                 READY   STATUS    RESTARTS   AGE
airflow-postgresql-0                 1/1     Running   0          4m17s
airflow-scheduler-56b8fc88fc-6d84d   3/3     Running   0          4m17s
airflow-statsd-75f567fd86-st744      1/1     Running   0          4m17s
airflow-triggerer-69fd8cd56f-p4nb7   1/1     Running   0          4m17s
airflow-webserver-6c598dd6d6-vx445   1/1     Running   0          4m17s
```

## Airflow WebUI
To make the Airflow WebUI accessible a port-forward must be set up :
```
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace airflow
```
If the port forward is successful, you can access the Airflow installation in the Kubernetes cluster using a web browser via ``http://127.0.0.1:8080``. The username/password is admin/admin.

## Test of the installation
If everything worked, two DAGs should now be visible in Airflow, hello_world and hop. hello_world runs a simple Python operator that prints a string to the logfile. "hop" starts the hop pipeline from ```sources/hop/generated_rows.hpl``.
During the execution of the DAGs you can use ``kubectl get po -n airflow``` to watch how additional PODs are opened and disappear again.

## Apache Hop in Apache Airflow
Apache Hop is now integrated into the Apache Airflow container and can be used to implement DAGs that execute Hop objects. DAG scripts and Hop sources are fetched into the container at runtime of the POD via git-sync. In the repository described here, DAG and hop sources can be found in the ```sources/dag`` and ```sources/hop`` directories, respectively. In the ``airflow/values.xml`` git-sync is configured to sync the ```sources`` directory from the repo directly into the container.

The hop configuration within the container also ensures that the necessary hop "default" project points to the synced ```sources/hop``. It should be noted that the synced files are located in a read-only directory. This prevents e.g. metadata objects from being written to the default locations by Hop.

Under ```sources/hop`` some files and directories are therefore mandatory:
* project-config.json 
* metadata mit einigen Unterverzeichnissen und den run-configurations
* die pipeline-log/-probe workflow-log Verzeichnisse müssen angelegt sein, da Hop beim Start eines Jobs abbricht, wenn sie nicht anlegbar sind

## Links

* https://k8s-docs.netlify.app/en/docs/tasks/tools/install-minikube/
* https://airflow.apache.org/docs/helm-chart/stable/index.html
* https://airflow.apache.org/docs/helm-chart/stable/manage-dags-files.html
* https://www.youtube.com/watch?v=39k2Sz9jZ2c
* https://phoenixnap.com/kb/install-minikube-on-ubuntu
