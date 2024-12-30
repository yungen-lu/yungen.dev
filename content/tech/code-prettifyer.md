---
title: Code-Prettifyer project
description: “Testing leads to failure, and failure leads to understanding.” - Burt Rutan
date: 2021-01-11T00:00:00+08:00
lastmod: 2024-12-28T11:11:53+08:00
draft: false
category: "[[Posts]]"
tags:
  - posts
---
## 前言

本篇內容主要是說明我如何用Docker、traefik、nginx軟體，以及JavaScript、PHP、C⋯⋯等等程式語言，做出一個可以讓使用者透過網頁輸入自己的程式碼後，對其進行分析、檢查以及排版的網頁應用程式。

## 概念發想

因著我是大一才開始真正接觸程式，從編輯器開始接觸了vim。因著vim的特性，可以自定義很多快捷鍵、以及安裝許多由其他人寫的plugin。其中就有plugin可透過其他人寫的[linter](https://zh.wikipedia.org/wiki/Lint)直接對程式碼進行分析，找出程式碼中可能存在的錯誤。這個plugin帶給我許多方便，可惜的是絕大部分的linter在windows環境安裝起來有點麻煩，為了能推廣linter給使用windows環境的朋友，我便有一個想法。就是做一個網頁使使用者只要複製貼上自己的程式碼，按一個鍵，就能輸出分析結果甚至格式化程式碼。

## 過程

### 伺服器

要能架設網頁首先就是要有自己的伺服器，因著我手邊剛好有一台raspberry pi我就直接在上面安裝ubuntu 20.4LTS。

安裝完基本設定都搞定後，抱著好玩與嘗試的心態我沒有照原本的計畫直接在raspberry上安裝web server而是想要嘗試看看用docker來運行web server，基本上我就照著官方給的[資料](https://docs.docker.com/engine/install/ubuntu/)安裝就成功了。接著我照著其他人給的建議安裝了[portainer](https://www.portainer.io/)讓我可以透過網頁UI來管理 docker。

到目前為止，我只能透過內網連到我的伺服器，如果要從外面的網路連到伺服器的話就需要有一個固定ip。因著我家裡是安裝中華電信的網路，所以我可以直接到他們的網站申請一組固定ip。申請完後直接設定raspberry pi 讓它能透夠PPPoE的方式上網。

這時候我已經可以直接在外網ssh到伺服器，或是直接在瀏覽器輸入ip位址打開portianer頁面了。但如果其他要連到我的網頁的話就要輸入一串很難記的數字。為了讓我的網頁更好記得，我就在name.com上申請了自己網域名。

![my domain](https://i.imgur.com/U7f4Ahp.png)

申請完後在設定裡添加一個A record指向自己server的位址

![截圖 2021-01-06 下午2.59.10](https://i.imgur.com/imow1Xc.png)

這樣就可以透過網域名連到我的伺服器了。

但這樣就會遇到一個問題—我有多個網域名都指向同一個ip位址，而我有不同的網頁，這樣伺服器則怎麼判斷使用者想要連到哪一個網頁？這時候，就要使用[反向代理](https://zh.wikipedia.org/wiki/%E5%8F%8D%E5%90%91%E4%BB%A3%E7%90%86)來處理這個問題。 透過反向代理伺服器解析request的HTTP header可以知道使用者要連到那一個網頁伺服器，再將使用者連到該伺服器。

在網路上查了些資料後我選擇traefik作為反向代理的軟體。

![traefik revers proxy](https://i.imgur.com/B5CNqU5.png)

在設定traefik時我基本就是照官網的建議設定，其中還有參考Digitalocean的[教學文章](https://www.digitalocean.com/community/tutorials/how-to-use-traefik-v2-as-a-reverse-proxy-for-docker-containers-on-ubuntu-20-04)修改traefik.toml以及traefik_dynamic.toml檔案，以下是我的docker-compose.yml的一部分

```yaml
services:
  
  traefik:
    build:
      context: "./Dockerfiles/traefik/"
      dockerfile: "Dockerfile"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./Dockerfiles/traefik/traefik.toml:/traefik.toml:ro
      - ./Dockerfiles/traefik/traefik_dynamic.toml:/traefik_dynamic.toml

    networks: 
      - web
    container_name: traefik
```

以及Dockerfile

```dockerfile
FROM traefik:latest
RUN touch /acme.json #建立acme.json檔案
RUN chmod 600 /acme.json #更改檔案權限
```

其中必須注意acme.json這個檔案，因為traefik會自動向[Let's Encrypt](https://letsencrypt.org/)申請TLS，這個檔案是存放憑證的，所以要另外在伺服器中建立一個。透過Let's Encrypt申請憑證後使用者能透過https協議連到網站。

設定完traefik後接著要安裝網頁伺服器，我選擇使用nginx搭配php-fpm，以下是我的docker-compose.yml的一部分

```yaml
  nginx:
    build:
      context: "./Dockerfiles/nginx/"
      dockerfile: "Dockerfile"
    labels:
      - traefik.http.routers.nginx.rule=Host(`blog.yungen.studio`,`app.yungen.studio`)
      - traefik.http.routers.nginx.tls=true
      - traefik.http.routers.nginx.tls.certresolver=lets-encrypt
      - traefik.http.services.nginx.loadbalancer.server.port=80
      - traefik.http.middlewares.gzip.compress=true
      - traefik.http.routers.nginx.middlewares=gzip
    networks:
      - internal  #確認跟php在同一個網路裡
      - web
    volumes:
      - ./blog.yungen.studio:/var/www/blog.yungen.studio  #確認路徑與php的一樣
      - ./app.yungen.studio:/var/www/app.yungen.studio
      - ./nginxlog/:/var/log/nginx/

    container_name: nginx
  php:
    build:
      context: "./Dockerfiles/php/"
      dockerfile: "Dockerfile"
    container_name: php
    networks:
      - internal  #確認跟nginx在同一個網路裡
    volumes:
      - ./blog.yungen.studio:/var/www/blog.yungen.studio
      - ./app.yungen.studio:/var/www/app.yungen.studio  #確認路徑與nginx的一樣
    labels:
      - traefik.enable=false
```

以及Dockerfile

```dockerfile
#Nginx的檔案
FROM nginx:alpine
COPY ./nginx.conf /etc/nginx/ #將設定檔複製到Container裡
COPY ./sites-enabled /etc/nginx/
COPY ./nginxconfig.io /etc/nginx/ 
#PHP的檔案
FROM php:fpm-alpine
RUN apk update  #安裝網頁需要的程式
RUN apk add cppcheck
RUN apk add build-base
RUN apk add shadow
RUN usermod -u 1000 www-data #更改www-data權限讓php能執行以上程式
RUN groupmod -g 1000 www-data
```

其中要注意的是php和nginx的volume設定要掛載相同的位址。我自己因為設定錯誤位址而花了不少時間除錯。 

docker 的部分設定完後接著設定nginx。我用Digitalocean所提供的[工具](https://www.digitalocean.com/community/tools/nginx)設定，稍微更改了一些有關php的設定

```ini
# fastcgi settings
fastcgi_pass                  php:9000;  #"php"需要改成在docker-compose.yml中設定的名稱
fastcgi_index                 index.php;
```

設定完這部分後基本上就完成大部分的設定了，接著只要在伺服器中輸入：

```
docker network create web
```



```shell
docker-compose up -d
```

docker 就會把所有軟體架設好。

### 網頁

#### 大略流程圖

![flowchart (1)](https://i.imgur.com/5fUlz1z.png)

#### 前端

收先需要建立一個輸入介面讓使用者能輸入程式碼，我使用[Codejar](https://medv.io/codejar/)作為我的輸入介面，我照這Github上的指示建立一個div元素給予它一個名稱為"editor"的id屬性，並在javascript 中加入以下

```javascript
import { CodeJar } from 'https://medv.io/codejar/codejar.js';

const highlight = (editor) => {
  editor.textContent = editor.textContent;
  hljs.highlightBlock(editor);
};
const editor = document.querySelector('.editor');
const jar = new CodeJar(editor, highlight);
```

這樣就可以在網頁中產生一個程式碼編輯器。接著需要建立三個按鈕，一個執行檢查，一個執行上傳，一個執行格式化。

```html
<button type="button" id="button1">format</button>
<button type="button" id="button2">check</button>
<input  type="file" name="filesubmit" id="filesubmit"/>
```

接著在javascript中用querySelector選擇按鈕並監聽按鈕的動作

```javascript
let b1 = document.querySelector('#button1');
let b2 = document.querySelector('#button2');
let b3 = document.querySelector('#filesubmit');

b1.addEventListener('click', sendb1Req);
b2.addEventListener('click', sendb2Req);
b3.addEventListener('change', sendb3Req)
```

對每一個按鈕都會執行不同的函示，以button1為例

```javascript
function sendb1Req() {
  let code = jar.toString();  //用codejar的API將使用者輸入的程式碼給code這個變數
  let codeObject = {
    codeKey: code,  //將code變數放在codeObject這個object裡面
    filenamekey: 'tmpfile.c',
  };
  axios
    .post('postData.php', codeObject)  //傳送POST request給'postData.php'其中包含codeObject
    .then((res) => {
      console.log(res.data);
      return axios.get('formatOrder.php', {  //接受到伺服器的response後再傳送GET request 給'formatOrder.php'
        params: { filenamekey: 'tmpfile.c' },
      });
    })
    .then((res) => {
      console.log(res.data);
      jar.updateCode(res.data);  //將回傳的資料（格式化過的程式碼）更新編輯器內的程式碼
    })
    .catch((err) => {
      console.log('ERR');  //假如在其中過程失敗的話在console中輸出'ERR'
      console.log(err);
    });
}
```

上述例子中，我使用[axios](https://github.com/axios/axios)來發送AJAX request。

#### 後端

從前端接受資料後需要經過後端處理再將資料回傳，我主要是用php來處理資料的接收與傳送以及request，並根據request執行我寫的三個c程式formatBracket、removeSpace以及parseError還有我正在使用的cppcheck這個程式。

以下是我處理接受資料的兩個程式

```php
//postData.php
<?php
if (isset($_POST)) {
  header('Content-Type: application/json');  //因為傳送資料的格式為json
  $body=file_get_contents("php://input");
  $object = json_decode($body, true);  //需要把json轉換為php看得懂的格式
  $input = $object["codeKey"];
  $filename=$object["filenamekey"];  //codescript.js在傳送GET request 時有包含一個filenamekey 以及codeKey值
  $fptr = fopen('./upload/'.$filename, "w");
  fwrite($fptr, $input);
  fclose($fptr);
  echo json_encode("SUCCESS");
}

?>
```

```php
//uploadData.php
<?php
if ($_FILES['filesubmit']['error'] === UPLOAD_ERR_OK) {  //檢查有沒有上傳成功
  if (!is_dir("upload")) {  //若upload資料夾不存在的話就新增一個
    mkdir("upload", 0755, true);
  }

  if (file_exists('upload/' . $_FILES['filesubmit']['name'])) {
    unlink('upload/' . $_FILES['filesubmit']['name']);  //若檔案存在的話刪除
  } 
    $file = $_FILES['filesubmit']['tmp_name'];
    $dest = 'upload/' . $_FILES['filesubmit']['name'];
    move_uploaded_file($file, $dest);  //將檔案從暫存移動到upload/
    echo json_encode("SUCCESS!");
}

?>
```

成功接受到資料後，要對資料進行處理。首先是格式化程式碼的程式，我寫的程式主要功能是格式化大括號裡面的程式碼，先將所有的tab轉換成space後再將多餘的space移除，接著將code排版為以下格式

```c
{
    /* ... */
    {
       /* ... */
    }
}
```

removeSpace主要是將tab轉換為空白後移除多餘的空白跟換行

```c
void replaceTab(char *string) {
    char *qtr;
    while ((qtr = strchr(string, '\t')) != NULL) {  //尋找到\t後替換為空白
        *qtr=' ';
    }
}
char *myrmspace(char *string) {
    char *ptr = string;  //ptr作為讀取資料的指標
    char *out = malloc(sizeof(char) * strlen(string) + 1);
    char *qtr = out;  //qtr作為寫入資料的指標
    while (*ptr == ' ') {
        ptr++;
    }
    while (*ptr) {
        while ((*ptr == ' ') && *(ptr + 1) == ' ') { //若重複找到空白ptr向前跳過
            ptr++;
        }
        *qtr++ = *ptr++;  //遇到正常字元則依序寫入
    }
    if (*(ptr - 1) == ' ') {  //因為我是一行一行讀取，所以當所有字都讀取完後，檢查有沒有trailing space
        qtr--;
    }
    *qtr = '\0';
    return out;
}
```

再來是格式化的程式formatBracket，以下是簡化的流程圖

![formatflow (2)](https://i.imgur.com/pDElWTL.png)

這是簡化過的版本，以下是formatBracket的一部分

```c
void formatBracket(char **input, char **output, int(*indentlevelPtr)) {
    while (*(*input)) {
        if (*(*input) == '{') {
            /* 
             省略
             ...
            */
            addindent(output, indentlevelPtr); //根據indentlevel進行縮排處理
            *(*output)++ = *(*input)++;
            replaceNewline(input, output);
            (*indentlevelPtr)++; //indentlevel + 1
            formatBracket(input, output, indentlevelPtr);
        }

        if (*(*input) == '}') {
             /* 
             省略
             ...
            */
            (*indentlevelPtr)--; //indentlevel - 1
            addindent(output, indentlevelPtr);
            *(*output)++ = *(*input)++;
            replaceNewline(input, output);
            return;
        }
        if (*((*output) - 1) == '\n') {
            addindent(output, indentlevelPtr);
        }
        if (*(*input) == ';' && *(*input + 1) != '\n') {
            if (*(*input - 1) == ';' || *(*input) + 1 == ';') {
                *(*output)++ = *(*input)++;
                continue;
            }
            *(*output)++ = *(*input)++;
            *(*output)++ = '\n';
            continue;
        }

        *(*output)++ = *(*input)++;
    }
}
```

首先在main函示中建立兩個指標，一個負責讀取一個負責寫入，接著將兩個指標傳入formatBracket函示中近處理大括號，處理完後再將結果輸出。程式碼本身還包含許多例外處理，例如遇到'{'要當作一般的字處理，還有很多判斷式判斷是否要換行⋯⋯等等。

再來是cppcheck 這個程式，這個程式是開放原始碼是由很多人一起寫的，這邊主要解釋我使用它時會給予的arugument

```shell
 cppcheck --enable=all --suppress="missingIncludeSystem" ./formatBracket.c 2>&1
```

* --enable：cppcheck可檢查很多方面的錯誤，選擇“all”表示要檢查所有方面的錯誤
* --suppress：cppcheck可以檢查自己寫的header file，但目前不會用到，所以我選擇不顯示關於header 方面的錯誤
* 2>&1：將stderr導向stdout，方便等等處理

接下來是處理cppcheck輸出的程式parseError，由觀察可知cppcheck輸出的資訊是有一定格式的，以下舉例

```
test.c:11:1: error: Memory leak: tmp [memleak]
}
^
test.c:15:9: style: Unused variable: a [unusedVariable]
    int a;
        ^
```

第一個是檔案名，再來是行數、列數、錯誤類別（還有warning、information等等）、錯誤資訊、括號內的錯誤ID以及最後的錯誤程式碼。可以由這格式透過正規表示式將所需要的資訊擷取出來

```
[^ ]+:([0-9]+):([0-9]+):[\r\n\t\f\v ]+([^:]+):[\r\n\t\f\v ]+(.+)\[+(.+)\]
```

1. "\[^ \]+:"匹配所有非空格的字元直到遇到“：”
2. "([0-9]+)"匹配所有數字直到“：”並將此數字放在一個Capturing Group中
3. "[\r\n\t\f\v ]+(\[^:\]+)"匹配whitespace特殊字元之後將所有非“：”的字元放在一個Capturing Group中
4. "(.+)\\["匹配所有字元直到"["（"["需加上\）並將匹配結果放在一個Capturing Group中
5. "(.+)\]"匹配所有字元直到"]"並將匹配結果放在一個Capturing Group中

這樣我們就有五個Capturing Group分別代表行數、列數、錯誤類別、錯誤資訊、錯誤ID。程式碼的部分參考了這篇[文章](https://cynthiachuang.github.io/Regular-Expressions-in-C/)將所需要的資料依據上述表示式提取出來。以下是parseError的一部分

```c
#include <stdio.h>
#include <regex.h>
int main() {
    char input[1024];
    regex_t regexCompile;
    char* pattern = "[^ ]+:([0-9]+):([0-9]+):[\r\n\t\f\v ]+([^:]+):[\r\n\t\f\v ]+(.+)\\[+(.+)\\]";  // 定義表示式（"\"要escape）
    int groupCnt = 6;
    regmatch_t groupArray[groupCnt];  //匹配後的結果存放在這裏
    int lineCnt = 0;
    int checkCnt = 0;
    if (regcomp(&regexCompile, pattern, REG_EXTENDED)) {  //將表示式編譯成特定的資料格式
        printf("Could not compile regular expression.\n");
        return -1;
    }

    while (fgets(input, sizeof(char) * 1024, stdin) != NULL) {
        if (removeline(input) == 1) {
            continue;
        }
        rmln(input);
        lineCnt++;
        if (regexec(&regexCompile, input, groupCnt, groupArray, 0) == 0) {  //對input進行匹配
            checkCnt++;
            unsigned int g = 1;
            for (g = 1; g < groupCnt; g++) {
                char sourceCopy[strlen(input) + 1];
                strcpy(sourceCopy, input);
                sourceCopy[groupArray[g].rm_eo] =
                    '\0';  //在sourcCopy為原始資料的複製，將groupArray[g].rm_eo（第g個Group的結束位址）（rm_so,rm_eo是regmatch_t
                           //struct的其中兩個參數，紀錄匹配結果開始與結束位址）位址賦予'\0'
                if (g == 3) {  //對第三個Group進行處理（錯誤類別）轉換為toastr模組能參數
                    replaceInfo(sourceCopy + groupArray[g].rm_so);
                }
                printf("%s#", sourceCopy + groupArray[g].rm_so);  // sourceCopy 位址加上groupArray[g].rm_so（開始位址）等於第g個Group的字串起始位址
            }
            printf("?");
        }
    }
    if ((checkCnt == 0) && (lineCnt == 0)) { //如果沒有錯誤的話輸出此行
        printf("success# #?");
    }
    regfree(&regexCompile); //清空 regexCompile的内容
}
```

接著用迴圈分別將Capturing Group裡的值依照以下格式輸出

```
行數#列數#錯誤類別#錯誤資訊#錯誤ID#?行數#列數 ....
```

“#”以及“?”特殊符號是為了方便等等回傳時能將資料轉換為JSON的格式。

#### 輸出

format的部分php在接受到一個GET request後將剛剛儲存的程式碼經過removeSpace、 formatBracket的處理後將結果回傳。當瀏覽器收到回傳值後，再透過Codejar提供的函示更新編輯器裡的程式碼。

```php
//formatOrder.php
<?php
if (isset($_GET)){
    $filename = $_GET['filenamekey'];
    if((file_exists('./app/removeSpace')==false)&& file_exists('./app/removeSpace.c')){
        shell_exec('gcc ./app/removeSpace.c -o ./app/removeSpace');
    }
    if((file_exists('./app/formatBracket')==false)&& file_exists('./app/formatBracket.c')){
        shell_exec('gcc ./app/formatBracket.c -o ./app/formatBracket');
    }
    if ((file_exists('./app/formatBracket')==false)||(file_exists('./app/removeSpace')==false)) {  //檢查執行命令所需程式，若無則直接編譯，若失敗則回傳"Opps"
    echo "Opps...";
    }else{
    $cmd = "cat "."./upload/$filename "."| "."./app/removeSpace "."| "."./app/formatBracket";
    $output = shell_exec($cmd);
    echo $output;
    unlink("./upload/$filename");
    }
}

?>
```

cppcheck的部分就相對複雜，cppcheck的輸出結果再經過parseError的格式化後，將其儲存在一個php的變數中，接著使用php的[函示](https://www.php.net/manual/en/function.explode.php)explode("pattern",variable)將格式化結果依據"pattern"作為斷點分割，分割後將結果個別放到變數中。

```php
//excuteOrder.php
<?php
if (isset($_GET))
    if((file_exists('./app/parseError')==false)&& file_exists('./app/parseError.c')){
        shell_exec('gcc ./app/parseError.c -o ./app/parseError');
    }
    if (file_exists('./app/parseError')==false) {  //檢查執行命令所需程式，若無則直接編譯，若失敗則回傳Opps...
    echo "Opps...";
    }else{
    $filename = $_GET['filenamekey'];
    $cmd = 'cppcheck '.'--enable=all '.'--suppress=missingIncludeSystem '."./upload/$filename".' 2>&1 '.'| ./app/parseError';
    $output = shell_exec($cmd);
    $arrayOfGroup=explode("#?",$output); //用"#?"作為分割依據
    $jsonGroup=[];
    for($i = 0;$i <count($arrayOfGroup)-1;$i++){
        $tmp=explode("#",$arrayOfGroup[$i]);  用"#"作為分割依據
        array_push($jsonGroup,$tmp);
    }
    echo json_encode($jsonGroup);
    unlink("./upload/$filename");
    }

?>
```

首先用"#?"作為分割依據可以得到類似以下結果

```
array 
  0 => string '12#1#error#Memory leak: tmp #memleak' 
  1 => string '25#12#info#Local variable 'a' shadows outer variable #shadowVariable'
  2 => string '17#7#info#Unused variable: a #unusedVariable'
```

接著再對陣列中每一個元素使用一次explode函示，這次用"#"作為分割依據並將結果根據原本列位址放在一個陣列中的第i位址

```
[["12","1","error","Memory leak: tmp ","memleak"],["25","12","info","Local variable 'a' shadows outer variable ","shadowVariable"],["17","7","info","Unused variable: a ","unusedVariable"]]
```

接著使用json_encode函示將資料轉為JSON格式並回傳

當瀏覽器收到回傳值時，axios會自動將JSON轉換為一個Object這時候將包含所需資料的Object傳入以下函示（Context\[i\]\[0,1,2...\]解讀為第i個錯誤，而其中0,1,2...代表行、列、錯誤類別⋯⋯）

```javascript
function toastFunc(Context) {
  for (let i = 0; i < Context.length; i++) {
    console.log(Context[i][2]);
    toastr[Context[i][2]](Context[i][3], 'Line: ' + Context[i][0]);
  }
}
```

這裡我使用一個叫做[toastr](https://github.com/CodeSeven/toastr)的plugin，可以在頁面上顯示toast，例如像以下這樣

![截圖 2021-01-08 上午10.28.29](https://i.imgur.com/S3eYu7a.png)

toastr["style"]\("content","title"\)"style"是更改toast的風格，對應的是cppcheck輸出的錯誤類別，在parseError程式中已經先將cppcheck輸出的錯誤類別全部替換成taostr可以接受的參數。"content"對應的是錯誤資訊，"title"是更改toast的標題，對應的是cppcheck輸出的行數。toastr的一些設置（大小、樣式、顯示位址等等）可以透過更改toastr.options物件裡的參數設定。最後的結果會像以下這樣

![截圖 2021-01-08 上午10.33.10](https://i.imgur.com/pmONLvt.jpg)

## 結論與可改進之處

現在網站已經可以做到接受使用者的程式碼後分析並回傳錯誤資訊與格式化的結果，但其中還有許多可以改進的地方

1. 如果使用著上傳一個毫無錯誤的程式碼，無法顯示“無法找到錯誤”之類的資訊。
2. cppcheck本身可以lint C以及C++的程式碼，目前只能處理C的程式碼
3. formatBracket程式只能處理大括號裡的程式碼
4. parseError無法處理cppcheck輸出的”錯誤程式碼“
5. 可以讓使用著選擇Codejar字體樣式以及Syntax Highlighting的風格等等



## 心得

我覺得做這個project讓我學習到很多新東西，像是Javascript、php這些跟C很不一樣的程式語言，還有Docker、Markdown、Github等等，最重要的是能藉著這個project將計算機概論教的網路概念實際操作一次，讓我對網路方面有更深的領悟。整體而言，做這個project是很快樂的。尤其是看到自己寫的功能如預期運作的時候，那種興奮感就好像第一次寫Hello World一樣。雖然說這只是老師出的一份作業而已，但我後續還會繼續更新我的網站，把我課堂上、網路上的學到的新東西加進去。

## 連結

* https://code.yungen.studio/ 我的project網址
* https://app.yungen.studio/ 我的project網址（備份，有可能刪除）
* https://github.com/yungen-lu/Code-Prettifyer 我的Github Repository

## 參考連結

* https://developer.mozilla.org/
* https://stackoverflow.com/
* https://www.w3schools.com/
* https://masteringjs.io/
* https://www.udemy.com/course/javascript-beginners-complete-tutorial/
* https://www.udemy.com/course/the-web-developer-bootcamp/