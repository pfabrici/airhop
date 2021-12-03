# Jenkins on Kubernetes
Kleiner Showcase, der folgende Dinge zeigen soll :
* wie wird Jenkins in einem eigenen Namespace in Kubernetes ausgeführt
* Persistierung der Jenkins Konfigurationen in einem Persistent Volume ( hier : NFS )
* Jenkins soll BuildJobs auf dem Kubernetes Cluster in eigenen Pods starten
Umgebung ( lokal ) :
* Ubuntu 20.4 Installation 
* minikube
* NFS 

# Installation des NFS

```
sudo apt-get update && apt-get install nfs-server nfs-common
sudo mkdir -p /srv/nfs/jenkins
```

/etc/exports konfigurieren : 
```
#
/srv/nfs          *(rw,sync,no_subtree_check,crossmnt,fsid=0)
/srv/nfs/jenkins  *(rw,sync,no_subtree_check)
```

Danach neustarten :
```sudo exportfs -ra```

# Jenkins Deployment ausführen 
Ein kleines Shellscript hilft bei der Ausführung des Deployments :
```
jenkins.sh [up|down|init]
```

Mit ```kubectl cluster-info``` kann die IP des Kubernetes Clusters herausgefunden werden.
Der NodePort des Services mit ``` kubectl get svc -n jenkins```

# 

# Links / Doku
https://levelup.gitconnected.com/running-jenkins-inside-a-kubernetes-cluster-bd86822d487
https://itnext.io/scaling-jenkins-build-agents-with-kubernetes-pods-8c89f87ba0d3
https://www.youtube.com/watch?v=Zzwq9FmZdsU&t=2s
https://airflow.apache.org/docs/helm-chart/stable/index.html
https://kubernetes.io/de/docs/concepts/workloads/pods/

https://opensource.com/article/20/5/helm-charts
