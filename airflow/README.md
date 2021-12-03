# Airflow on local Kubernetes

Installation einer Airflow Installation auf einem lokalen
Kubernetes Cluster. Verwendung des Kubernetes Executors,
d.h. die Tasks der DAGs werden auf short-lived Pods ausgeführt.

Die DAG Definitionen werden regelmäßig aus git in die Pods synchronisiert.

Es wird ein custom Airflow Container verwendet, der es erlaubt eigene
Provider / Module zu verwenden.


## Links

https://airflow.apache.org/docs/helm-chart/stable/manage-dags-files.html
https://www.youtube.com/watch?v=39k2Sz9jZ2c
