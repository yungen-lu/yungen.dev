---
title: traefik & let’s encrypt
description: A traefik & let's encrypt tutorial I wrote for AInimal meetings
date: 2022-02-04T00:00:00+08:00
lastmod: 2024-12-27T17:55:09+08:00
draft: false
---
# 前言

在上一篇文章中介紹如何設置 reverse proxy ，這篇將會介紹如何使用 let’s encrypt 讓 traefik 支援 HTTPS 連線。

# 簡單介紹 let’s encrypt

let’s encrypt 是個憑證頒發機構，與其他憑證頒發機構不同的是 let’s encrypt 提供免費的憑證，只要客戶端達成某些條件，向 let’s encrypt 證明其擁有某個網域名時，let’s encrypt 就會免費提供數位憑證給客戶端。

# traefik & let’s encrypt

traefik 本身支援使用最常見的 TLS 憑證，也支援透過 [ACME](https://zh.wikipedia.org/wiki/%E8%87%AA%E5%8B%95%E6%86%91%E8%AD%89%E6%9B%B4%E6%96%B0%E7%92%B0%E5%A2%83) 的方式向支援 ACME 頒發憑證的機構自動獲取數位憑證（此範例使用 let’s encrypt）。此外，let’s encrypt 所頒發的數位憑證有有效期限，traefik 會在到期時自動更新數位憑證。

# let’s encrypt 運作機制

在申請憑證時，最重要的步驟就是向 let’s encrypt 證明你擁有此網域。let’s encrypt 有提供三種方式：

1. HTTP-01 考驗：let’s encrypt 會給客戶端一個 token ，客戶端要將 此 token 放在網頁伺服器`http://<YOUR_DOMAIN>/.well-known/acme-challenge/<TOKEN>` 中，let’s encrypt 之後就會向該網址發送請求，若 let’s encrypt 成功拿到 token 後就會認定此網域的確為客戶所擁有，並頒發數位憑證。
2. DNS-01 考驗：let’s encrypt 會給客戶端一組字串 ，客戶端將此字串以 TXT 紀錄放在 DNS 中，接著 let’s encrypt 就會去查詢相對應的 DNS TXT 紀錄。若有成功查詢到 TXT 紀錄，就會認定此網域的確為客戶所擁有，並頒發數位憑證。
3. TLS-ALPN-01 考驗：此方法較為少見，詳細可參考[官網](https://letsencrypt.org/zh-tw/docs/challenge-types/)。

traefik 支援以上三種驗證方式，且會在快到期時自動更新憑證。接下來的範例中會使用 HTTPS-01 以及 DNS-01 考驗。

# traefik 設定範例

以下文章將會接續上一篇文章，設置 whoami 以及 podinfo 使我們能透過 HTTPS 連線。

在開始教學前，請先確認你的環境滿足以下條件

- 可以使用 Docker 以及 Docker-Compose
- 擁有一個 domain name
- 確保 port 80、443 開啟且並沒有被其他程式使用

## 準備步驟

traefik 是透過 ACME 的方式去獲取憑證，所以我們要事先準備好一個檔案存放這些憑證。

- 建立 `acme.json` 檔案
    
    延續上一篇文章，我們在 traefik-example 目錄中建立一個空的 acme.json 檔案
    
    ```bash
    touch acme.json
    ```
    
    接著將他的權限改為 600 （只有擁有者有讀寫權限）
    
    ```bash
    chmod 600 acme.json
    ```
    
- 將此檔案 mount 到 traefik container 中
    
    `docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      traefik:
        image: "traefik:v2.5"
        container_name: "traefik"
        ports:
          - "80:80"
        volumes:
          - "/var/run/docker.sock:/var/run/docker.sock:ro"
          - "./traefik.yaml:/traefik.yaml:ro"
          - "./acme.json:/acme.json"
      ## 以下省略...
    ```
    

當我們設定好 HTTPS 後使用者會通過 port 443 與 traefik 連線，所以我們先在 docker-compose 中打開 port 443

- 打開 port 443
    
    `docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      traefik:
        image: "traefik:v2.5"
        container_name: "traefik"
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - "/var/run/docker.sock:/var/run/docker.sock:ro"
          - "./traefik.yaml:/traefik.yaml:ro"
          - "./acme.json:/acme.json"
      ## 以下省略...
    ```
    

別忘了新增一個 entrypoint

- 新增 “websecure” entrypoint
    
    `traefik.yaml`
    
    ```yaml
    entryPoints:
      web:
        address: ":80"
      websecure:
    		address: ":443"
    ```
    

## 透過 HTTP-01 考驗

- 設置 certificates resolvers
    
    以下範例設置名稱為 `lets-encrypt-resolver` 的 certificates resolvers ，並指定其驗證方法為 HTTP-01 考驗，且儲存憑證的檔案名為 `acme.json` 。
    
    `traefik.yaml`
    
    ```yaml
    entryPoints:
      web:
        address: ":80"
      websecure:
    		address: ":443"
    certificatesResolvers:
      lets-encrypt-resolver: # <- 這邊為使用者自己定義的名稱
        acme:
          #caServer: <https://acme-staging-v02.api.letsencrypt.org/directory>
          storage: acme.json
          email: example@gmail.com # 這邊寫自己常用的 email 信箱，當憑證快到期時就會提醒你
          httpChallenge:
            entryPoint: web
    ```
    
    這邊需要注意的是因為我們使用 HTTP-01 考驗 `entryPoint` 這邊一定要設置為 port 80 的 entrypoint 。
    
    traefik 的 `caServer` 預設為 [`*<https://acme-v02.api.letsencrypt.org/directory`>](https://acme-v02.api.letsencrypt.org/directory) 若改成* [`https://acme-staging-v02.api.letsencrypt.org/directory`](https://acme-staging-v02.api.letsencrypt.org/directory) 則 traefik 就會頒發測試用憑證。
    
- 設置 whoami podinfo
    
    當我們設置完 certificates resolvers 後，需要指定 router 使用 certificates resolvers ，讓所有進入到此 router 的 https request 能夠成功解密。
    
    以下範例將名稱為 `whoami-router` 的 router 設定其 certificates resolvers 為 `lets-encrypt-resolver`
    
    `docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      traefik:
        image: "traefik:v2.5"
        container_name: "traefik"
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - "/var/run/docker.sock:/var/run/docker.sock:ro"
          - "./traefik.yaml:/traefik.yaml:ro"
          - "./acme.json:/acme.json"
      whoami:
        image: "traefik/whoami"
        container_name: "whoami"
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.whoami-router.entrypoints=web"
          - "traefik.http.routers.whoami-router.rule=Host(`whoami.$MY_DOMAIN`)" # 在此範例相當於 "whoami.ainimal.io"
          - "traefik.http.services.whoami-service.loadbalancer.server.port=80"
          - "traefik.http.routers.whoami-router.service=whoami-service"
          - "traefik.http.routers.whoami-router.tls.certresolver=lets-encrypt-resolver"
     ## 以下省略...
    ```
    
    別忘了將 whoami container 的 entrypoint 改成 https （範例為：`websecure`）
    
    ```yaml
    version: "3.8"
    
    services:
      traefik:
        image: "traefik:v2.5"
        container_name: "traefik"
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - "/var/run/docker.sock:/var/run/docker.sock:ro"
          - "./traefik.yaml:/traefik.yaml:ro"
          - "./acme.json:/acme.json"
      whoami:
        image: "traefik/whoami"
        container_name: "whoami"
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.whoami-router.entrypoints=websecure"
          - "traefik.http.routers.whoami-router.rule=Host(`whoami.$MY_DOMAIN`)" # 在此範例相當於 "whoami.ainimal.io"
          - "traefik.http.services.whoami-service.loadbalancer.server.port=80"
          - "traefik.http.routers.whoami-router.service=whoami-service"
          - "traefik.http.routers.whoami-router.tls.certresolver=lets-encrypt-resolver"
     ## 以下省略...
    ```
    

## 透過 DNS-01 考驗

透過 DNS-01 考驗申請憑證的好處就是 DNS-01 考驗支援 wild card 憑證，舉例來說如果我申請了 *.ainimal.io 的憑證，[podinfo.ainimal.io](http://podinfo.ainimal.io)、[whoami.ainimal.io](http://whoami.ainimal.io) 就可以直接使用，不需要另外申請。

在設置前請先確認你的 DNS 機構是否在[支援名單中](https://doc.traefik.io/traefik/https/acme/#providers)。

- 設置 certificates resolvers
    
    以下範例設置名稱為 `lets-encrypt-resolver` 的 certificates resolvers ，並指定其驗證方法為 DNS-01 考驗，且儲存憑證的檔案名為 `acme.json` 。
    
    `traefik.yaml`
    
    ```yaml
    entryPoints:
      web:
        address: ":80"
      websecure:
    		address: ":443"
    certificatesResolvers:
      lets-encrypt-resolver: # <- 這邊為使用者自己定義的名稱
        acme:
          #caServer: <https://acme-staging-v02.api.letsencrypt.org/directory>
          storage: acme.json
          email: example@gmail.com # 這邊寫自己常用的 email 信箱，當憑證快到期時就會提醒你
          dnsChallenge:
            provider: cloudflare
            resolvers:
              - "1.1.1.1:53"
              - "8.8.8.8:53"
    ```
    
    這邊需要注意的是要將 `provider` 設定為自己的 DNS 機構。
    
- 設置 DNS-01 考驗所需要的環境變數
    
    traefik 在執行 DNS-01 考驗時，是透過 API 的方式去更改 DNS TXT 紀錄，所以我們要提供 DNS 機構的 API token 等相關資訊給 traefik 。請參考支援名單中每個 provider 所需要的環境變數名稱，traefik 會根據你設定的 provider 從環境變數中獲取資訊。
    
    以下範例使用 cloudflare 作為 provider ，需要 `CF_API_EMAIL` `CF_API_KEY` 環境變數
    
    `.env`
    
    ```bash
    MY_DOMAIN=ainimal.io
    DEFAULT_NETWORK=mynetwork
    CF_API_EMAIL=example@gmail.com
    CF_API_KEY=93klas1ks93cnqi22kk8fk
    ```
    
- 設置 whoami podinfo
    
    當我們設置完 certificates resolvers 後，需要指定 router 使用 certificates resolvers ，讓所有進入到此 router 的 https request 能夠成功解密。
    
    以下範例將名稱為 `whoami-router` 的 router 設定其 certificates resolvers 為 `lets-encrypt-resolver`
    
    `docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      traefik:
        image: "traefik:v2.5"
        container_name: "traefik"
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - "/var/run/docker.sock:/var/run/docker.sock:ro"
          - "./traefik.yaml:/traefik.yaml:ro"
          - "./acme.json:/acme.json"
      whoami:
        image: "traefik/whoami"
        container_name: "whoami"
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.whoami-router.entrypoints=websecure"
          - "traefik.http.routers.whoami-router.rule=Host(`whoami.$MY_DOMAIN`)" # 在此範例相當於 "whoami.ainimal.io"
          - "traefik.http.services.whoami-service.loadbalancer.server.port=80"
          - "traefik.http.routers.whoami-router.service=whoami-service"
          - "traefik.http.routers.whoami-router.tls.certresolver=lets-encrypt-resolver"
     ## 以下省略...
    ```
    

若我們想要用到 DNS-01 考驗才有的功能 wild card 憑證就會需要修改 entrypoint 的 tls 設定，此處的 tls 設定為預設設定，若使用者在 router 中有自定義 tls 設定則會自動忽略此設定。

- 修改 entrypoint 設定
    
    traefik.yaml
    
    ```yaml
    entryPoints:
      web:
        address: ":80"
      websecure:
    		address: ":443"
        http:
          tls:
            certResolver: "lets-encrypt-resolver"
            domains:
              - main: "yungen.me"
                sans:
                  - "*.yungen.me"
    certificatesResolvers:
      lets-encrypt-resolver:
        acme:
          #caServer: <https://acme-staging-v02.api.letsencrypt.org/directory>
          storage: acme.json
          email: example@gmail.com # 這邊寫自己常用的 email 信箱，當憑證快到期時就會提醒你
          dnsChallenge:
            provider: cloudflare
            resolvers:
              - "1.1.1.1:53"
              - "8.8.8.8:53"
    ```
    
- 設置 whoami podinfo
    
    當我們設置過預設 tls 後就不需要再特別設定 tls 了。
    
    `docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      traefik:
        image: "traefik:v2.5"
        container_name: "traefik"
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - "/var/run/docker.sock:/var/run/docker.sock:ro"
          - "./traefik.yaml:/traefik.yaml:ro"
          - "./acme.json:/acme.json"
      whoami:
        image: "traefik/whoami"
        container_name: "whoami"
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.whoami-router.entrypoints=websecure"
          - "traefik.http.routers.whoami-router.rule=Host(`whoami.$MY_DOMAIN`)" # 在此範例相當於 "whoami.ainimal.io"
          - "traefik.http.services.whoami-service.loadbalancer.server.port=80"
          - "traefik.http.routers.whoami-router.service=whoami-service"
     ## 以下省略...
    ```