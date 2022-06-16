#!/bin/bash

kubectl -n pre-satelease delete pod --selector=app=ms-backend-gateway
