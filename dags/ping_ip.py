from datetime import datetime
from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python_operator import PythonOperator
import os


def ping_ip():
    ip_address = "192.168.115.16"  # My laptop IP
    response = os.system("ping -c 1 " + ip_address)

    if response == 0:
        pingstatus = "Network Active."
    else:
        pingstatus = "Network Error."
    print("\n *** Network status for IP Address=%s is : ***" % ip_address)
    print(pingstatus)

    return pingstatus

dag = DAG('ping_ip', description='Ping network IP',
          schedule_interval='0 12 * * *',
          start_date=datetime(2017, 3, 20), catchup=False)

ping_ip = PythonOperator(task_id='ping_ip', python_callable=ping_ip, dag=dag)

ping_ip
