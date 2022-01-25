from datetime import datetime
from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python_operator import PythonOperator
from pythonping import ping
import os


def ping_ip():
    ip_address = "192.168.115.16"  # My laptop IP
    response = ping(ip_address, count=1)

    if response.success :
        pingstatus = "Ok"
    else:
        pingstatus = response.error_message
    print("\n *** Network status for IP Address=", ip_address, " is : ", pingstatus, " ***" )

    return pingstatus

dag = DAG('ping_ip', description='Ping network IP',
          schedule_interval='0 12 * * *',
          start_date=datetime(2017, 3, 20), catchup=False)

ping_ip = PythonOperator(task_id='ping_ip', python_callable=ping_ip, dag=dag)

ping_ip
