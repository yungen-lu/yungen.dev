---
title: gRPC short note
description: A note I wrote for AInimal meetings
date: 2022-03-04T00:00:00+08:00
lastmod: 2025-02-09T14:38:10+08:00
draft: false
category: "[[Posts]]"
tags:
  - posts
---

# What is gRPC

在了解什麼是 gRPC 之前需要先解釋一下什麼是 RPC(Remote Procedure Call)。RPC 是一種程式之間溝通的方式，A 程式可以呼叫 B 程式去執行一些 function ，也可以把他想像為在一個程式中呼叫另一個程式的 function 。gRPC 為 google 推出的一個 framework 能實現上述提到的功能。

# Why

未來如果要將 backend microservices 化，會遇到一個問題就是 services 之間要如何溝通，當然我們能夠沿用 HTTP 作為溝通的方式，但 HTTP 有幾個缺點：

1. 與 gRPC 相比、傳輸同一筆資料需要消耗更多頻寬。舉例：
    
    json: `{”id”:2}` (9 bytes)
    
    xml: `<id>42</id>` (11 bytes)
    
    protobuf: `0x08 0x2a` (2 bytes) → gRPC 的傳輸方式
    
2. 傳輸方式只有一種（client 發送 request, server 給予 response）
    
3. ...
    

總而言之 gRPC 的方式更適合 microservice 架構

更詳細的比較可以參考這篇：

[比較 gRPC 服務與 HTTP API](https://docs.microsoft.com/zh-tw/aspnet/core/grpc/comparison?view=aspnetcore-6.0)

# How

假設一個情境，我們要請我們的 database service 幫我們儲存一個使用者的聊天紀錄，並回傳是否成功儲存。在這個情境下，database service 為 gRPC 的 server 端，我們的程式為 client 端。

在傳輸任何資料前，我們需定義我們傳輸資料的格式以及 server 端會如和處理資料。gRPC 傳輸資料預設是透過 protocol buffer ，所以我們需要寫一個 proto file，裡面會描述資料是如何傳輸的。

首先我們需要寫使用的 protobuf 版本

`databaseService.proto`

```protobuf
syntax = "proto3";
```

接著我們定義我們傳輸資料的格式。

```protobuf
message UserMessage {
  int32 to = 1;
  string content = 2;
  string type = 3;
  string reply = 4;
}

message Reply {
  bool ok = 1;
}
```

接著我們定義我們的 service 名稱並該 service 的 method

```protobuf
service DataBase {
  rpc StoreMessage (UserMessage) returns (Reply) {}
}
```

整體的 protobuf code 長這樣

```protobuf
syntax = "proto3";
service DataBase {
  rpc StoreMessage (UserMessage) returns (Reply) {}
}
message UserMessage {
  int32 to = 1;
  string content = 2;
  string type = 3;
  string reply = 4;
}

message Reply {
  bool ok = 1;
}
```

上述範例中我們定義了一個 service 並且指定該 service 有一個 method 為 `StoreMessage` ，我們在 client 端可以直接呼叫 `StoreMessage` function 並傳入相對應的 `UserMessage`， server 端就會接受到該筆資訊，並會依照 `Reply` 回傳資料給 client 。透過範例我們可以發現 client 端不需要去在乎 `StoreMessage` 是怎麼去實現的，實現的邏輯就交給 server 端。

接下來我會以 Go 為 client 端、 Node.js 為 server 端來示範兩種不同語言是如何透過 gRPC 溝通。

## Server 端

收先安裝必要的 packages

```bash
npm install @grpc/grpc-js @grpc/proto-loader
```

因為我們使用 typescript 所以我們可以用 `proto-loader-gen-types` 根據我們寫的 databaseService.proto 自動生成許多 interface 讓我們可以使用 ide 的 type hint ，並且確保我們寫的程式都有符合 databaseService.proto 裡的規定。

我們先建立一個 `proto` 資料夾並將 `databaseService.proto` 放入其中，接著在 command line 中輸入以下指令

```bash
$(npm bin)/proto-loader-gen-types --longs=String --enums=String --defaults --oneofs --grpcLib=@grpc/grpc-js --outDir=proto/ proto/databaseService.proto.proto
```

我們可以在 `proto` 資料夾中找到三個新的檔案 `DataBase.ts` `databaseService.ts` `Reply.ts UserMessage.ts`

我們將必要的 package 與 自動生成的 interfaces 載入

```tsx
import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';const packageDefinition = protoLoader.loadSync('./proto/databaseService.proto')
const proto = (grpc.loadPackageDefinition(packageDefinition) as unknown) as ProtoGrpcType;
import { ProtoGrpcType } from './proto/databaseService'
import { DataBaseHandlers } from './proto/DataBase'
import { UserMessage } from './proto/UserMessage'
import { Reply } from './proto/Reply'
```

載入我們寫的 `databaseService.proto`

```tsx
const packageDefinition = protoLoader.loadSync('./proto/databaseService.proto')
const proto = grpc.loadPackageDefinition(packageDefinition)
```

接著我們寫一個 function 去實作 `StoreMessage`

```tsx
function MyStoreMessage(call:grpc.ServerUnaryCall<UserMessage,Reply>,callback:grpc.sendUnaryData<Reply>){
	if(call.request){
		// request 裡面包含了在 databaseService.proto 定義的 UserMessage 資料，我們這邊直接 console log 出來
		console.log(call.request.to)
		console.log(call.request.content)
		console.log(call.request.type)
		console.log(call.request.reply)
		// ....
		// 對資料庫進行操作
		// ....
	}
	callback(null,{ok: true}) //callback 為回傳給 client 端的資料，需要符合 databaseService.proto 定義的 Reply 格式
}
```

接著新增一個 server 並將我們寫的 function 傳入

```tsx
const server = new grpc.Server();
server.addService(proto.DataBase.service,{StoreMessage:MyStoreMessage})
```

監聽一個 port 並開啟 server

```tsx
server.bindAsync(
  '0.0.0.0:30030',
  grpc.ServerCredentials.createInsecure(),
      (err: Error | null, port: number) => {
      if (err) {
        console.error(`Server error: ${err.message}`);
      } else {
        console.log(`Server bound on port: ${port}`);
        server.start();
      }
    }
)
```

## Client 端

安裝 [Protocol buffer ****compiler](https://grpc.io/docs/protoc-installation/)

安裝必要的 modules

```bash
go get -u google.golang.org/grpc
```

我們先建立一個 `proto` 資料夾並將 `databaseService.proto` 放入其中，接著我們要在 databaseService.proto 中新增一個設定

```protobuf
option go_package = "example.com/grpc-example-client/proto"; // 此為 go 程式 go package 的路徑
```

在 commandline 中輸入以下指令

```bash
protoc --go_out=. --go_opt=paths=source_relative \\
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \\
    proto/databaseService.proto
```

我們可以在 `proto` 資料夾中找到兩個新的檔案 `databaseService.pb.go` `databaseService_grpc.pb.go` 這兩個檔案包含了所有的 interface 以及 type

我們先 import 必要的 module 並在 main function 中建立與 server 端的連線

```go
package main

import (
	pb "example.com/grpc-example-client/proto"
	"google.golang.org/grpc"
)

func main() {
	conn, _ := grpc.Dial("localhost:30030", grpc.WithInsecure(), grpc.WithBlock())
	defer conn.Close()
}
```

接著新增一個 client

```go
client := pb.NewDataBaseClient(conn)
```

我們產生一筆資料並藉由呼叫 `client.StoreMessage` 執行 RPC

```go
userMsg := &pb.UserMessage{
		To:      2,
		Content: "test message",
		Type:    "message",
		Reply:   "",
	}
reply, _ := client.StoreMessage(context.Background(), userMsg)
fmt.Println(reply.Ok)
```
