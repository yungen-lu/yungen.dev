---
title: MQTT short note
description: A note I wrote for AInimal meetings
date: 2022-03-18T00:00:00+08:00
lastmod: 2025-02-09T14:38:00+08:00
draft: false
category: "[[Posts]]"
tags:
  - posts
---

# What is mqtt

mqtt 是個基於 Pub/Sub 模式的 protocol ，主要會由一個 message broker 與多個 client 組成。

# What is Pub/Sub

在 Pub/Sub 的傳輸模式下訊息的傳輸不會以一對一的方式傳送訊息，而是將訊息發布到一個 Topic 中，而所有有訂閱該 Topic 的用戶都會收到訊息。可以想像為 slack 的頻道，我可以在 d1 中發訊息（發布訊息到 d1 這個 topic），而只會有在 d1 這個頻道的使用者收到訊息（有訂閱 d1 topic 的使用者）。不過在 Pub/Sub 模式下收到訊息不會知道是誰發佈的。（除非在訊息中有寫）

## MQTT 傳輸模式

### QOS

1. QoS 0: 最多一次傳送：client 傳送訊息後不在乎訊息是否真的有其他 client 端收到。
2. QoS 1: 至少一次傳送：client 傳送訊息後會等待接收方回應，如果沒有回應則會重新再傳一次。（此方法可以確保訊息會送達，但不會確保訊息不會重複）
3. QoS 2: 正好一次傳送：與 QoS 2 相似但會確保訊息不會重複。

# How

目前打算使用 emqx 作為 message broker ，讓所有使用者作為 client 端，同時 chat services 也會作為 client 發布訊息給所有 client 端。

## Client

以下我會用 typescript 搭配 MQTT.js 示範

import mqtt 並定義設定

```tsx
import mqtt from 'mqtt'

const options = {
  		clean: true, // 當 clean 設為 true 時，每次 client 連線到 broker 後不會接續上一次的 session
      connectTimeout: 4000,
      clientId: 'typescript_mqtt_client', // clientId 必須為獨一的，不能同時有相同 clientid 的 client 連上 message broker
}
const client = mqtt.connect("ws://localhost:8083/mqtt", options)
```

接著我們定義我們在不同 event 的 callback function。

```tsx
client.on('connect',()=>{
  client.subscribe('mytopic')
})

client.on('message', (topic, message) => {
  console.log('receive message：', topic, message.toString())
})

client.on('reconnect', (error) => {
    console.log('reconnecting:', error)
})

client.on('error', (error) => {
    console.log('Connection failed:', error)
})
```

以下我會用 golang 搭配 [p](http://github.com/eclipse/paho.mqtt.golang)aho-mqtt-golang 示範

先定義 mqtt 的設定

```go
	opts := mqtt.NewClientOptions()
	opts.AddBroker("tcp://localhost:1883").SetClientID("golang_mqtt_client")
	opts.ConnectTimeout = 2 * time.Second
	opts.WriteTimeout = 2 * time.Second
	opts.KeepAlive = 10
	opts.PingTimeout = 2 * time.Second
	opts.ConnectRetry = true
	opts.AutoReconnect = true
```

定義 mqtt 在發生某些 event 時的 call back function

```go
	opts.OnConnectionLost = func(c mqtt.Client, e error) {
		log.Println("connection lost")
	}
	opts.OnConnect = func(c mqtt.Client) {
		log.Println("connected")
	}
	opts.OnReconnecting = func(c mqtt.Client, co *mqtt.ClientOptions) {
		log.Println("reconnecting")
	}
```

成功與 message broker 建立連線後發布一個訊息到 “mytopic” 中。

```go
	client := mqtt.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		panic(token.Error())
	}
	log.Println("Connection is up")
	t := client.Publish("mytopic", 1, false, "test")
	go func() {
		<-t.Done()
		if t.Error() != nil {
			log.Println("ERROR")
		}
	}()
	time.Sleep(6 * time.Second)
	client.Disconnect(250)
```

如果剛剛的 typescript client 還在運行，應該會看到 `receive message： mytopic test` 。

# EMQx

## **Extension Hook**

當 emqx 發生某些 events 時，會對我們的 grpc server 端呼叫 rpc call 傳送訊息給我們，我們可以根據 emqx 傳給我們的資料做相對應的處理。

舉例：

```protobuf
service HookProvider {
	rpc OnClientConnect(ClientConnectRequest) returns (EmptySuccess) {};	
	rpc OnMessagePublish(MessagePublishRequest) returns (ValuedResponse) {};
	rpc OnMessageDelivered(MessageDeliveredRequest) returns (EmptySuccess) {};
}
```

當有使用者上線後會 emqx 會呼叫 `OnClientConnect` 我們可以將該使用者的狀態設定為上線，當使用者傳送訊息時 emqx 會呼叫 `OnMessagePublish` 我們可以將該訊息存入至 DB 中。

## **Extension Protocol**

與 extension hook 概念相似，不同的是我們不再是以監聽的概念，而是 emqx 會傳訊息給我們，我們需要回傳訊息給 emqx ， emqx 會根據我們回傳的訊息做相對應的動作。

舉例：

```protobuf
service ConnectionAdapter {
	rpc Authenticate(AuthenticateRequest) returns (CodeResponse) {};
	rpc Publish(PublishRequest) returns (CodeResponse) {};
}
enum ResultCode {
  SUCCESS = 0;
  UNKNOWN = 1;
  CONN_PROCESS_NOT_ALIVE = 2;
  REQUIRED_PARAMS_MISSED = 3;
  PARAMS_TYPE_ERROR = 4;
  PERMISSION_DENY = 5;
}

message CodeResponse {
  ResultCode code = 1;
  string message = 2;
}
```

當使用者嘗試透過 mqtt 連到我們的 message broker 時， emqx 會呼叫 `Authenticate` ，我們收到 `AuthenticateRequest` 訊息後可以檢視該使用者並回傳 `ResultCode` 告訴 emqx 該不該讓此使用者連線。

# 補充

- exhook
    
    ```protobuf
    service HookProvider {
    
      rpc OnProviderLoaded(ProviderLoadedRequest) returns (LoadedResponse) {};
    
      rpc OnProviderUnloaded(ProviderUnloadedRequest) returns (EmptySuccess) {};
    
      rpc OnClientConnect(ClientConnectRequest) returns (EmptySuccess) {};
    
      rpc OnClientConnack(ClientConnackRequest) returns (EmptySuccess) {};
    
      rpc OnClientConnected(ClientConnectedRequest) returns (EmptySuccess) {};
    
      rpc OnClientDisconnected(ClientDisconnectedRequest) returns (EmptySuccess) {};
    
      rpc OnClientAuthenticate(ClientAuthenticateRequest) returns (ValuedResponse) {};
    
      rpc OnClientCheckAcl(ClientCheckAclRequest) returns (ValuedResponse) {};
    
      rpc OnClientSubscribe(ClientSubscribeRequest) returns (EmptySuccess) {};
    
      rpc OnClientUnsubscribe(ClientUnsubscribeRequest) returns (EmptySuccess) {};
    
      rpc OnSessionCreated(SessionCreatedRequest) returns (EmptySuccess) {};
    
      rpc OnSessionSubscribed(SessionSubscribedRequest) returns (EmptySuccess) {};
    
      rpc OnSessionUnsubscribed(SessionUnsubscribedRequest) returns (EmptySuccess) {};
    
      rpc OnSessionResumed(SessionResumedRequest) returns (EmptySuccess) {};
    
      rpc OnSessionDiscarded(SessionDiscardedRequest) returns (EmptySuccess) {};
    
      rpc OnSessionTakeovered(SessionTakeoveredRequest) returns (EmptySuccess) {};
    
      rpc OnSessionTerminated(SessionTerminatedRequest) returns (EmptySuccess) {};
    
      rpc OnMessagePublish(MessagePublishRequest) returns (ValuedResponse) {};
    
      rpc OnMessageDelivered(MessageDeliveredRequest) returns (EmptySuccess) {};
    
      rpc OnMessageDropped(MessageDroppedRequest) returns (EmptySuccess) {};
    
      rpc OnMessageAcked(MessageAckedRequest) returns (EmptySuccess) {};
    }
    ```
    
- exproto
    
    ```protobuf
    service ConnectionAdapter {
    
      // -- socket layer
    
      rpc Send(SendBytesRequest) returns (CodeResponse) {};
    
      rpc Close(CloseSocketRequest) returns (CodeResponse) {};
    
      // -- protocol layer
    
      rpc Authenticate(AuthenticateRequest) returns (CodeResponse) {};
    
      rpc StartTimer(TimerRequest) returns (CodeResponse) {};
    
      // -- pub/sub layer
    
      rpc Publish(PublishRequest) returns (CodeResponse) {};
    
      rpc Subscribe(SubscribeRequest) returns (CodeResponse) {};
    
      rpc Unsubscribe(UnsubscribeRequest) returns (CodeResponse) {};
    }
    
    service ConnectionHandler {
    
      // -- socket layer
    
      rpc OnSocketCreated(stream SocketCreatedRequest) returns (EmptySuccess) {};
    
      rpc OnSocketClosed(stream SocketClosedRequest) returns (EmptySuccess) {};
    
      rpc OnReceivedBytes(stream ReceivedBytesRequest) returns (EmptySuccess) {};
    
      // -- pub/sub layer
    
      rpc OnTimerTimeout(stream TimerTimeoutRequest) returns (EmptySuccess) {};
    
      rpc OnReceivedMessages(stream ReceivedMessagesRequest) returns (EmptySuccess) {};
    }
    ```
