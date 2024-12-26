---
title: traefik tutorial
description: A traefik tutorial I wrote for AInimal meetings
date: 2022-02-01T00:00:00+08:00
lastmod: 2024-12-27T01:19:59+08:00
draft: false
---
# 前言

當我們在架設後端 service 的時候很常會遇到要將 service A 和 service B 放在同一個伺服器中運行，這時候會遇到一個問題：要如何設置 Endpoint 讓使用者能分別使用 service A 與 service B 呢？

- 方法ㄧ：將 service A 暴露（expose?）在 port A （例如：9000），將 service B 暴露在與 port A 不同的 port B （例如：3000），這樣使用者就能分別從 \<伺服器 IP\>:\<portA\> 、\<伺服器 IP\>:\<portB\> （例如：140.116.241.66:9000,140.116.241.66:3000）存取 service A 與 B
- 方法二：使用 reverse proxy ，設置 reverse proxy 監聽 port C （例如：80），使用者只要向 \<伺服器 IP\>:\<portC\> 發送 request ， reverse proxy 會根據使用者請求分別將 request 轉送到不同的 service （例如：140.116.241.66:80/A → service A、140.116.241.66:80/B → service B）。以下文章會介紹如何使用 [traefik](https://traefik.io/traefik/) 作為 reverse proxy

# 簡單介紹 traefik

在 traefik 的官網中是如此介紹 traefik 的

> Traefik is an [open-source](https://github.com/traefik/traefik) _Edge Router_ that makes publishing your services a fun and easy experience.

traefik 的功能其實不只有 reverse proxy 而已，還有 load balancing 、 api gateway ...等功能，本篇文章將 focus 在 reverse proxy 上。

### 與其他 reverse proxy 的區別

traefik 與其他 reverse proxy 軟體（例如： Nginx、HAProxy、Caddy ...）最大的區別在於 traefik 在設置上能與 docker 緊密結合（Label Based，接下來會仔細說明）也能與許多環境配合（kubernetes ,docker swarm...）。

# traefik 設置的架構

## Configuration Discovery

在我們一般的認知中當我們要設置軟體時，通常會想到透過更改 config file 或透過 command line argument 去更改軟體設定，但 traefik 的設定比較複雜。在 traefik 中有所謂的 provider （例如：Docker, Kubernetes IngressRoute...），traefik 會透過這些 provider 去拿到設置的詳細資訊（當然也可透過 config file 或 command line 設定）。以下以 docker-compose 舉例：

`example-docker-compose.yaml`

```yaml
version: "3.8"

services:
  whoami:
    image: "containous/whoami"
    labels:
      - "traefik.enable=true" # <- 注意這裏
```

當我們設置 traefik 使用 Docker 作為 provider 時，traefik 就會從 docker 抓取 container 資料，以上述 docker-compose 為例，當 traefik 發現有 container 的 labels 為 `traefik.enable=true` 時，就會認定該 container 需要用到 traefik 的功能，並根據其設定為該 container 開啟 traefik 的功能。

## Routing & Load Balancing

### EntryPoints

在設定所有的 routing 之前，我們必須先設定 traefik 的 entrypoint 。所有的 request 都會從 entrypoint 進入，再由 traefik 轉送到指定的 service 。以下以 traefik 的 static config file 為例：

`traefik.yaml`

```yaml
entryPoints:
  web: # <- 這邊為使用者自己定義的名稱
    address: ":80"
  web2:
		address: ":8080"
```

以上述的 config file 為例，若我們要發送 request 到伺服器，就必須發送到 `<伺服器 IP>:<80>` 或 `<伺服器 IP>:<8080>`

### Routers

當 request 由 entrypoint 進入後要如何決定將其轉發到哪一個 service 就需要透過設定 Routers 解決。在設定 Router 時需要考慮以下幾點：

1. EntryPoint: traefik 預設 router 會監聽每一個 entryPoint ，但我們也可以設定成指監聽某幾個 entryPoint 。以下範例我們設置一個 Router 名稱為 “myrouter” 並指定其 entryPoint 為 web2
    
    `example-docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      whoami:
        image: "containous/whoami"
        labels:
          - "traefik.enable=true"
    			- - "traefik.http.routers.myrouter.entrypoints=web2" # <- "myrouter" 為使用者自己定義的名稱
    ```
    
2. Rule: traefik 會根據使用者設定的 rule 決定 request 會到哪一個 router 。以下範例我們設置一個 rule 只讓 host 名稱為 `myserverdomainname.com` 的 request 進到此 router 。
    
    `example-docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      whoami:
        image: "containous/whoami"
        labels:
          - "traefik.enable=true"
    		  - "traefik.http.routers.myrouter.entrypoints=web2"
    			- "traefik.http.routers.myrouter.rule=Host(`myserverdomainname.com`)"
    ```
    
    以上範例為使用 `Host()` 來設置 rule ，其實還有許多方法 `Method()`、`Path()`...，更多方法可以參考[官網](https://doc.traefik.io/traefik/routing/routers/#rule)。
    
3. Priority: 在設置 rule 時可能發生 request 同時滿足兩個 router 的 rule，這時後需要設定 Priority 才能決定 request 要轉送到哪個 router 。
    
4. Middlewares: 我們可以針對 route 設定 middleware ，在 request 轉送到 service 之前對其處理，詳細的設置內容會在下一個章節提到。
    
5. Service: 每一個 route 必須指定一個 service 作為目標，當 request 進到該 router 後會轉送到目標 service 。這時候你可能會想：為什麼需要一個 service 呢？直接將 router 目標指向某個 後端應用程式的 url 就好了啊？原因是 traefik 除了提供 reverse proxy 以外還有 LoadBalancer 的功能，透過接下來的範例能更清楚了解。
    
    在 traefik 中需要另外設置 service ，我們先以 config file 的形式再以 docker-compose 的設定方式能更了解 traefik 的 service 是如何運作的。
    
    以下為 config file 形式的 service 設定，其中我們設置一個名稱為 `my-service` 的 service
    
    `traefik.yaml`
    
    ```yaml
    http:
      services:
        my-service:
          loadBalancer:
            servers:
            - url: "<http://private-ip-server-1/>"
            - url: "<http://private-ip-server-2/>"
    ```
    
    從以上的 config file 可以知道當 request 從某個 router 轉送到 “my-service” 時有可能被轉送到 "[http://private-ip-server-1/](http://private-ip-server-1/)" 以及 "[http://private-ip-server-2/](http://private-ip-server-2/)" 而會轉送到哪一個 url 是根據 [Round-robin](https://en.wikipedia.org/wiki/Round-robin_scheduling) 演算法。
    
    以下為 docker-compose 的設定，其中我們設置一個名稱為 `my-service` 的 service ，而這個 service 會與 container 的 port 80 連結。
    
    `example-docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      whoami:
        image: "containous/whoami"
        labels:
          - "traefik.enable=true"
    		  - "traefik.http.routers.myrouter.entrypoints=web2"
    			- "traefik.http.routers.myrouter.rule=Host(`myserverdomainname.com`)"
    			- "traefik.http.services.my-service.loadbalancer.server.port=80"
    			
    ```
    
    從以上 docker-compose 可發現若我們使用 labels 設定 service ， traefik 會自動將該 container 與設定的 service 連結，我們不需要像 config file 那樣設置 “url” 。
    
    最後我們需要將該 router 指向一個 service 。在以下範例我們設置 Router 名稱為 `myrouter` 指向一個名稱為 `my-service` 的 service
    
    `example-docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      whoami:
        image: "containous/whoami"
        labels:
          - "traefik.enable=true"
    		  - "traefik.http.routers.myrouter.entrypoints=web2"
    			- "traefik.http.routers.myrouter.rule=Host(`myserverdomainname.com`)"
    			- "traefik.http.services.my-service.loadbalancer.server.port=80"
    			- "traefik.http.routers.myrouter.service=my-service"
    ```
    
6. TLS: traefik 的功能也包含處理 HTTPS 連線，此設定較為複雜，可參考另一篇文章（未完成）。
    

## Middlewares

當 request 進入 router 後，我們可以設置 middlewares 對 request 進行處理，再送到 service 。

以下範例我們設置一個名稱為 `mymiddleware` 的 middleware 並使用 traefik 內建的 ratelimit ，最後我們將 `mymiddleware` 加到 `myrouter` 中。

`example-docker-compose.yaml`

```yaml
version: "3.8"

services:
  whoami:
    image: "containous/whoami"
    labels:
      - "traefik.enable=true"
		  - "traefik.http.routers.myrouter.entrypoints=web2"
			- "traefik.http.routers.myrouter.rule=Host(`myserverdomainname.com`)"
			- "traefik.http.services.my-service.loadbalancer.server.port=80"
			- "traefik.http.routers.myrouter.service=my-service"
		  - "traefik.http.middlewares.mymiddleware.ratelimit.average=100"
      - "traefik.http.middlewares.mymiddleware.ratelimit.burst=30"
      - "traefik.http.routers.myrouter.middlewares=mymiddleware"
```

# traefik 設定範例

以下文章將會實際設定 traefik 作為 reverse proxy ，並會使用 [whoami](https://github.com/traefik/whoami) 和 [podinfo](https://github.com/stefanprodan/podinfo) 作為示範 container。

在開始教學前，請先確認你的環境滿足以下條件

- 可以使用 Docker 以及 Docker-Compose
- 擁有一個 domain name
- 確保 port 80 開啟且並沒有被其他程式使用（不一定要使用 port 80 ，也可改成其他的）

本教學的伺服器環境為 debian bullseye docker 版本為 20.10.12 、 domain name 為 [ainimal.io](http://ainimal.io)

## 建立 directory

首先我們建立一個 directory ，接下來的設定檔案都會放在這個 directory 裡面。

```bash
mkdir traefik-example
cd traefik-example
```

## docker 環境設定

在設定 traefik 前我們必須建立一個 docker network ，以下範例我們建立一個名稱為 `mynetwork` 的 docker network 。

```bash
docker network create mynetwork
```

traefik 必需與 container 存在於同一個 docker network 才能順利運行，我們會將此 docker network 在接下來的 docker-compose 中設定為預設 network。

## 建立 docker-compose 環境變數

在 `traefik-example` 目錄下建立一個 `.env` 檔案，將所有 docker-compose 環境變數儲存在其中。此步驟並非必須，但之後若要更改 docker-compose 中的一些參數會較方便。

`.env`

```bash
MY_DOMAIN=ainimal.io
DEFAULT_NETWORK=mynetwork
```

## Traefik static configuration

在 `traefik-example` 目錄下建立一個 `traefik.yaml` 檔案。

我們通常會在此設置較為“靜態”的設定，以下範例我們設定其 entryPoints 與 providers

`traefik.yaml`

```yaml
entryPoints:
  web:
    address: ":80"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
```

注意 exposedByDefault 設定，因為這裏設置為 false 所以如果有 container 需要使用到 traefik 的功能就必須設定該 container 的 label 為 `"traefik.enable=true"`

## Docker-compose 設定

- 設定 traefik
    
    在 `traefik-example` 目錄下建立一個 `docker-compose.yaml` 檔案。
    
    我們需要先將 docker 的 socket mount 到 traefik container 中，這樣 traefik 才能從 docker socket 獲取資訊，接著將設定檔 traefik.yaml mount 到 traefik container 中。備註：其中 `....:ro` 代表 read only 。
    
    `docker-compose.yaml`
    
    ```yaml
    version: "3.8"
    
    services:
      traefik:
        image: "traefik:v2.5"
        ports:
          - "80:80"
        volumes:
          - "/var/run/docker.sock:/var/run/docker.sock:ro"
          - "./traefik.yaml:/traefik.yaml:ro" # 將上述建立的 static config mount 到 container 中
    ```
    
    接著我們設定 docker-compose 的 預設 network ，讓docker-compose 裡的 container 預設都是使用 `$DEFAULT_NETWORK` 作為 docker network 。
    
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
    networks:
      default:
        external:
          name: $DEFAULT_NETWORK # 在此範例相當於 "mynetwork"
    ```
    
    這時候我們執行 docker-compose `docker-compose -f docker-compose.yaml up -d` 來測試 traefik container 是否能正確運行。
    
    如果 traefik 成功啟動，在執行上述指令後應該會出現 “Creating traefik ... done” 。我們可以透過指令 `docker logs traefik` 來查看 logs ，若 traefik 成功讀取 config file 則 logs 中會出現 “Configuration loaded from file: /traefik.yml” 。
    
    這時候若我們在伺服器中執行 `curl localhost` 應該會出現 “404 page not found” ，我們也可以直接在本地端透過指令 `curl <伺服器 IP>` 測試或在瀏覽器輸入伺服器 IP 位置。
    
- 設定 domain name
    
    設置 domain name A record ，指向伺服器 IP，以下範例設置了 [whoami.ainimal.io](http://whoami.ainimal.io) 以及 [podinfo.yungen.me](http://podinfo.yungen.me) 兩個 A record
    
    ![截圖 2022-01-25 下午1.35.48](traefik%20tutorial-17ECCE36C3491852E6D39E0B1199840E.png)
    
- 設定 whoami podinfo container
    
    我們接下來在 docker-compose file 中增加whoami container
    
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
      whoami:
        image: "traefik/whoami"
        container_name: "whoami"
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.whoami-router.entrypoints=web"
          - "traefik.http.routers.whoami-router.rule=Host(`whoami.$MY_DOMAIN`)" # 在此範例相當於 "whoami.ainimal.io"
          - "traefik.http.services.whoami-service.loadbalancer.server.port=80"
          - "traefik.http.routers.whoami-router.service=whoami-service"
    networks:
      default:
        external:
          name: $DEFAULT_NETWORK
    ```
    
    從以上範例中可以看到我們設置了 Router: `whoami-router` 、 Service: `whoami-service` ，並將 Router 的 rule 設定為 `Host(`whoami.$MY_DOMAIN`)` ，也就是說只有 request host 為 `whoami.$MY_DOMAIN` 才能進入這個 Router 。
    
    設定 podinfo container 與 whoami 大同小異
    
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
      whoami:
        image: "traefik/whoami"
        container_name: "whoami"
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.whoami-router.entrypoints=web"
          - "traefik.http.routers.whoami-router.rule=Host(`whoami.$MY_DOMAIN`)" # 在此範例相當於 "whoami.ainimal.io"
          - "traefik.http.services.whoami-service.loadbalancer.server.port=80"
          - "traefik.http.routers.whoami-router.service=whoami-service"
      podinfo:
        image: "stefanprodan/podinfo"
        container_name: "podinfo"
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.podinfo-router.entrypoints=web"
          - "traefik.http.routers.podinfo-router.rule=Host(`podinfo.$MY_DOMAIN`)" # 在此範例相當於 "podinfo.ainimal.io"
          - "traefik.http.services.podinfo-service.loadbalancer.server.port=9898"
          - "traefik.http.routers.podinfo-router.service=podinfo-service"
    networks:
      default:
        external:
          name: $DEFAULT_NETWORK
    ```
    
    執行 `docker-compose -f docker-compose.yaml up -d`
    
    這時候若我們對 [whoami.ainimal.io](http://whoami.ainimal.io) 以及 [podinfo.ainimal.io](http://podinfo.ainimal.io) 發送 request 會得到相對應的 response ，如下圖：
    
    [whoami.ainimal.io](http://whoami.ainimal.io)
    
	![截圖 2022-02-04 下午7.49.44](traefik%20tutorial-436A7175BDF79A0C606BCC438413D643.png)
	
    [podinfo.ainimal.io](http://podinfo.ainimal.io)
    
	![截圖 2022-02-04 下午7.50.02](traefik%20tutorial-9B06ED14F596BE281FD07E3100C095D8.png)