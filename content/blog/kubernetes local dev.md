---
title: kubernetes local dev
description: A short note for Google Developer Student Club meetings
date: 2022-11-29T00:00:00+08:00
lastmod: 2025-02-09T14:38:03+08:00
draft: false
category: "[[Posts]]"
tags:
  - posts
---

# Introduction

在開發 kubernetes 相關的程式時為了確保程式能正確運行，需要一個 kubernetes 環境方便我們測試。我們不太可能每次測試都要另外開一個 gke ，太麻煩且浪費錢了，所以我們需要一些工具幫助我們在本地端架設 kubernetes cluster 來測試。

在本地端架設 kubernetes 有許多種方法下面列舉出一些較多人使用的工具

- [minikube](https://minikube.sigs.k8s.io/docs/)
- [k3d](https://k3d.io/)
- [kind](https://kind.sigs.k8s.io)
- [rancherdesktop](https://rancherdesktop.io)
- [colima](https://github.com/abiosoft/colima)

接下來會介紹如何安裝以及使用 minikube 以及 rancherdesktop

# minikube

## Prerequisite

- 安裝 docker 或 nerdctl
- 安裝 kubectl

## 安裝 minikube

### mac

```bash
brew install minikube
```

### linux(WSL)

```bash
curl -LO <https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64>
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

更多安裝方法請參考 [https://minikube.sigs.k8s.io/docs/start/](https://minikube.sigs.k8s.io/docs/start/)

### 啟動

```bash
minikube start
```

### 結束

```bash
minikube stop
```

### 檢查 kubectl context

```bash
kubectl config get-contexts
```

### 設定 kubectl context

```bash
kubectl config use-context <context-name>
```

# rancher desktop

## Prerequisite

- 無

## 安裝 rancher desktop

- 直接下載

```bash
brew install --cask rancher
```

### 檢查 kubectl context

```bash
kubectl config get-contexts
```

### 設定 kubectl context

```bash
kubectl config use-context <context-name>
```

# build and deploy

## minikube

```bash
eval $(minikube docker-env)
```

### 確定 docker context

```bash
docker context list
```

### deploy

`kubernetes.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-localdev-example
  labels:
    app: localdev-example
spec:
  selector:
    matchLabels:
      app: localdev-example
  template:
    metadata:
      labels:
        app: localdev-example
    spec:
      containers:
        - name: kube-localdev-example
          image: kube-localdev-example
          ports:
            - containerPort: 8080
          imagePullPolicy: Never
```

注意 `imagePullPolicy` 必須設定為 Never 或 IfNotPresent，設定為 Always （預設）kubernetes 會去 dockerhub pull 你的 image

```bash
kubectl apply -f kubernetes.yaml
```

# skaffold

## Prerequisite

- 一個 kubernetes cluster

## 安裝 skaffold

參考 [官網](https://skaffold.dev/docs/install/)

## 指令

```yaml
skaffold init
```

```yaml
skaffold dev
```

```yaml
skaffold
```

## local cluster 設定

```yaml
build:
  local:
    push: false
```
