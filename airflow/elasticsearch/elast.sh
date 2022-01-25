#!/bin/bash

helm install elasticsearch elastic/elasticsearch -f values.yaml  -n airflow
