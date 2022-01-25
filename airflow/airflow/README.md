
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace airflow

Airflow Deployment via helm upgraden 
```
helm upgrade --install airflow apache-airflow/airflow -n airflow -f values.yaml --debug
```
