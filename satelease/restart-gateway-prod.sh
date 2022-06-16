#!/bin/bash

kubectl -n prod-satelease delete pod --selector=app=ms-backend-gateway
