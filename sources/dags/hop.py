from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.bash_operator import BashOperator
from airflow.operators.python_operator import PythonOperator
from datetime import datetime, timedelta

import os
import subprocess

def run_hop_orig():
    os.chdir("/opt/hop")
    result=subprocess.getoutput("/opt/hop/hop-run.sh -r local -f generated_rows.hpl")
    print(result)

def run_hop():
    child = subprocess.Popen("/opt/hop/hop-run.sh -r local -f generated_rows.hpl", shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    for line in child.stdout.readlines():
        child.wait()
        print(line)
    return(child.returncode)

with DAG(dag_id='bash_dag', schedule_interval=None, start_date=datetime(2020, 1, 1), catchup=False) as dag:
    hop_task = PythonOperator(task_id='hop_task', python_callable=run_hop, dag=dag)
    sleep_task = BashOperator(task_id='sleep_task', bash_command="sleep 300")

    hop_task >> sleep_task
