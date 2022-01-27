from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.bash_operator import BashOperator
from airflow.operators.python_operator import PythonOperator
from datetime import datetime, timedelta

import os
import subprocess

def run_hop():
    os.chdir("/opt/hop")
    result=subprocess.getoutput("chmod -R 775 /opt/airflow/dags/repo/sources/hop/metadata")
    result=subprocess.getoutput("/opt/hop/hop-run.sh -r local -f generated_rows.hpl")
    print(result)

with DAG(dag_id='bash_dag', schedule_interval=None, start_date=datetime(2020, 1, 1), catchup=False) as dag:
    # Task 1
    dummy_task = DummyOperator(task_id='dummy_task')
    # Task 2
    bash_task = BashOperator(task_id='bash_task', bash_command="echo 'command executed from BashOperator'")
    # Task 3
    hop_task = PythonOperator(task_id='hop_task', python_callable=run_hop, dag=dag)
    # Task 4
    sleep_task = BashOperator(task_id='sleep_task', bash_command="sleep 300")
    dummy_task >> bash_task
    bash_task >> hop_task
    hop_task >> sleep_task
