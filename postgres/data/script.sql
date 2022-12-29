BEGIN TRANSACTION;

/****************************************************************************************************
    earthdistance: 做 geo location 用的 extensions
****************************************************************************************************/
alter user postgres password '6705Brian';

CREATE EXTENSION earthdistance CASCADE;

CREATE EXTENSION zhparser;
CREATE TEXT SEARCH CONFIGURATION zhcfg (PARSER = zhparser);
ALTER TEXT SEARCH CONFIGURATION zhcfg ADD MAPPING FOR a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z WITH simple;

CREATE OR REPLACE FUNCTION immutable_array_to_string(text[], text) 
    RETURNS text as $$ SELECT array_to_string($1, $2); $$ 
LANGUAGE sql IMMUTABLE;

SET TIMEZONE='Asia/Taipei';

 -- 運輸狀態 ... 準備中, 運送中, 收到貨, 換貨, 退貨
create type po_status as enum('preparing','shipping', 'received', 'exchange', 'returneds');
-- 支付平台 : Line Pay, Ali 支付寶
create type pay_method as enum('line', 'credit', 'atm', 'cvs', 'barcode', 'ali');
-- 運輸 狀態
create type shipping_status as enum('noaction','pending','notfound','transit','pickup','delievered','expired','undelivered','exception','InfoReceived');


/****************************************************************************************************
  後台人員
****************************************************************************************************/
create table staff (
  id                        bigint not null primary key,
  email                     varchar(50) not null unique,
  phone                     varchar(50),
  calling_code              varchar(10),
  email_confirmed           boolean not null default false,
  phone_confirmed           boolean not null default false,
  hash_password             varchar(150) not null,
  salt                      varchar(150) not null,
  securitystamp             varchar(150) not null,
  refresh_token             varchar(150) default null,
  refresh_token_expiry_time timestamp default null, 
  device_type               varchar(150),
  device_token              varchar(150),
  create_time               timestamp   default now(),
  update_time               timestamp   default null
);

/****************************************************************************************************
  客戶
****************************************************************************************************/
create table app_user (
    id                        bigint not null primary key,
    email                     varchar(50) not null unique,
    phone                     varchar(50),
    calling_code              varchar(10),
    email_confirmed           boolean not null default false,
    phone_confirmed           boolean not null default false,
    hash_password             varchar(150) not null,
    salt                      varchar(150) not null,
    securitystamp             varchar(150) not null,
    refresh_token             varchar(150) default null,
    refresh_token_expiry_time timestamp default null, 
    device_type               varchar(150),
    device_token              varchar(150),
    create_time               timestamp   default now(),
    update_time               timestamp   default null
);


/****************************************************************************************************
  商品種類
****************************************************************************************************/
create table category (
  id            bigserial not null primary key,
  name          varchar(50) not null,
  code          varchar(5) not null,

  create_time   timestamp   default now(),
  update_time   timestamp   default null
);

insert into category(id, name, code) values (1, '公仔系列', 'FE');
insert into category(id, name, code) values (2, '穿搭系列', 'FI');
insert into category(id, name, code) values (3, '拼圖系列', 'PI');
insert into category(id, name, code) values (4, '積木系列', 'BL');

/****************************************************************************************************
  產品
****************************************************************************************************/
create table product (
  id                    bigint not null primary key,     -- 商品 Identity
  code                  varchar(30) not null,            -- 商品代碼
  name                  varchar(50) not null,            -- 商品名稱  
  launch                boolean not null default false,  -- 商品現在是否上架中
  min_price             money not null,                  -- 商品方案中的最低價格
  max_price             money not null,                  -- 商品方案中的最高價格
  min_in_stock          Integer default 0,               -- 最小庫存(那個方案庫存最少)
  max_in_stock          Integer default 0,               -- 最大庫存(那個方案數存最多)
  min_shipment_quantity Integer default 0,               -- 最小出貨量(那個方案出貨量最少)
  max_shipment_quantity Integer default 0,               -- 最大出貨量(那個方案出貨量最多)
  information           varchar(150),                    -- 關於商品回洞信息之類的
  description           varchar(450),                    -- 關於商品的詳細訊息
  hashtags              varchar(50)[],                   -- 標籤
  cover                 varchar(150) not null,           -- 商品封面照片(注意資量一致問題)
  category_name         varchar(50) not null,            -- 商品種類名稱(注意資量一致問題)


  create_time           timestamp   default now(),
  update_time           timestamp   default null,

  category_id bigint,
  constraint fk_category foreign key(category_id) references category(id)
);

-- Description:
--     關於文字搜索商品的 Index
alter table product add column text_search_vector tsvector
generated always as ( 
  setweight(to_tsvector('zhcfg',name),'A') ||
  setweight(to_tsvector('zhcfg',immutable_array_to_string(ARRAY['迪士尼','公仔'],' ')),'B') ||
  setweight(to_tsvector('zhcfg',coalesce(description,'')),'C') 
) stored;

/****************************************************************************************************
  產品 - 方案 (比如說海賊王公仔產品,可以有方案A:路飛, B:索隆)
****************************************************************************************************/
create table model (
  id                 bigserial not null primary key,          -- 方案ID
  code               varchar(30) not null default 'standard', -- 方案代碼
  name               varchar(50) not null,                    -- 方案名稱
  price              money not null default 0,                -- 方案價格
  discount_price     money not null default 0,                -- 折扣後價格
  discount           numeric(2,1) not null,                   -- 幾折 
  cost_price         money not null default 0,                -- 成本價
  profit_percent     numeric(2,1) not null default 1.3,       -- 要多少成的利潤(cost_price * profit_percent = price)
  information        varchar(150) not null,                   -- 方案資訊
  shipment_quantity  Integer default 0,                       -- 方案出貨量
  in_stock           Integer default 0,                       -- 方案存貨量
  create_time        timestamp   default now(),               -- 方案建立時間

  -- 哪一個產癛的方案
  product_id bigint,
  constraint fk_product foreign key(product_id) references product(id)
);

/****************************************************************************************************
 運送地址
****************************************************************************************************/
create table address (
  id                bigserial not null primary key,
  country           varchar(100) default 'n\a',
  state             varchar(100) default 'n\a',
  county            varchar(100) default 'n\a',
  city              varchar(100) default 'n\a',
  district          varchar(100) default 'n\a',
  street            varchar(100) default 'n\a',
  postal_code       varchar(10) default 'n\a',
  latitude          double precision,
  longitude         double precision,
  formatted_address varchar(100),
  calling_code      varchar(10),
  phone_number      varchar(20),
  receiver          varchar(20),

  create_time      timestamp   default now(),
  app_user_id bigint,
  constraint fk_app_user foreign key(app_user_id) references app_user(id)
);


/****************************************************************************************************
 訂單
****************************************************************************************************/
create table purchase_request(
  id               bigserial not null primary key,

  pay              boolean default false,                -- 是否已經付過錢
  tax              money not null default 0,             -- 税
  delivery_fee     money not null default 0,             -- 運費

  tracking_number   varchar(100),                        -- 運單號
  shipping_status   shipping_status default 'noaction',  -- 運輸狀態  
  delivery_date     timestamp,                           -- 發貨日期
  date_of_taking    timestamp,                           -- 交貨日期
  done              boolean default false,               -- 是否已經確認收貨,結單了

  country           varchar(100) not null,            -- 國家
  city              varchar(100) not null,            -- 城市
  state             varchar(100) default 'n\a',       -- 州
  county            varchar(100) default 'n\a',       -- 郡
  district          varchar(100) not null,            -- 區
  street            varchar(100) not null,            -- 地址
  postal_code       varchar(10)  not null,            -- 郵遞區號
  latitude          double precision not null,        -- 經度
  longitude         double precision not null,        -- 緯度
  formatted_address varchar(100) not null,            -- 完整地址
  calling_code      varchar(10) not null,             -- 國家碼
  phone_number      varchar(20) not null,             -- 電話號碼
  receiver          varchar(20) not null,             -- 收件人名稱

  create_time     timestamp not null default now(),
  update_time     timestamp,
  
  -- 這個已經不用了, 可以考慮拔掉
  address_id bigint,
  constraint fk_address foreign key(address_id) references address(id),
  
  app_user_id bigint,
  constraint fk_app_user foreign key(app_user_id) references app_user(id)
);


/****************************************************************************************************
 交易
****************************************************************************************************/
create table payment (
  id                    bigserial not null primary key,   -- Transaction ID
  pay_method pay_method not null,                         -- 支付是利用什麼第三方平台
  amount                money not null,                   -- 交易金額
  description           varchar(50),                      -- 交易額外信息
  trade_no              varchar(30),                      -- 平台方的交易 ID
  charge_fee            money,                            -- 平台手續費

  create_time     timestamp not null default now(),

  purchase_request_id bigint,
  constraint fk_purchase_request foreign key(purchase_request_id) references purchase_request(id)
);

/****************************************************************************************************
 訂單
****************************************************************************************************/
create table purchase_order (
  id             bigserial not null primary key,      -- 單號
  quantity       smallint default 1,                  -- 個數
  unit_price     money not null,                      -- 單價
  price          money not null,                      -- 總價

  product_name   varchar(30),                         -- 商品名稱
  model_name     varchar(30),                         -- 方案名稱
  image          varchar(150),                        -- 商品示意圖
  description    varchar(200),                        -- 退換貨解釋
  rma            varchar(100),                        -- 退貨單號

  product_code   varchar(30) not null,                -- 商品代碼
  model_code     varchar(30) not null,                -- 方案代碼

  create_time timestamp not null default now(),
  update_time timestamp,

  model_id bigint,
  constraint fk_model foreign key(model_id) references model(id),

  purchase_request_id bigint,
  constraint fk_purchase_request foreign key(purchase_request_id) references purchase_request(id)
);

/****************************************************************************************************
 顧客評論
****************************************************************************************************/
create table review (
  id          bigserial not null primary key,
  comment     varchar(500),
  points      numeric(3,2) not null default 5.00,
  create_time timestamp not null,

  app_user_id bigint,
  constraint fk_app_user foreign key(app_user_id) references app_user(id)
);


/****************************************************************************************************
 多媒體 (包括照片和影片)
****************************************************************************************************/
create table media (
  id          bigserial not null primary key,
  url         varchar(150) not null,
  bucket      varchar(100) not null,
  key         varchar(100) not null,
  cover       boolean not null default false,
  arrangement smallint default -1,
  create_time timestamp not null default now(),

  product_id  bigint,
  constraint fk_product foreign key(product_id) references product(id),

  review_id bigint,
  constraint fk_review foreign key(review_id) references review(id)
);

/****************************************************************************************************
 商品 - 供應商
****************************************************************************************************/
create table product_vendor (
  id           bigserial not null primary key,
  name         varchar(50) not null,              -- 供應商名稱
  contact_info varchar(50) not null,              -- 供應商聯繫方式
  product_code varchar(150) not null,             -- 供應商提供的商品代碼(反正就是怎麼跟廠商說是這個貨)

  create_time  timestamp not null default now(),  
  update_time  timestamp,

  product_id  bigint,
  constraint fk_product foreign key(product_id) references product(id)
);


/****************************************************************************************************
 商品 - 補貨
****************************************************************************************************/
create table replenishment (
  id                bigserial  not null primary key,
  image             varchar(150) not null,                  -- 產品照片
  product_name      varchar(30) not null,                   -- 產品名稱
  product_code      varchar(30) not null,                   -- 產品代碼
  model_name        varchar(30) not null,                   -- 方案名稱          
  quantity          Integer not null,                       -- 購買數量
  unit_price        money not null,                         -- 購買單元價格
  tax               money not null default 0,               -- 税
  total_price       money not null,                         -- 購買總價
  note              varchar(150),                           -- 備註
  order_number      varchar(50),                            -- 訂單號
  tracking_number   varchar(50),                            -- 運單號
  rma               varchar(50),                            -- 退換貨 tracking number
  status            shipping_status default 'noaction',     -- 貨物狀態
  verification      boolean default false,                  -- 是否已核銷
  
  create_time       timestamp not null default now(),
  update_time       timestamp,

  -- 這次捕貨是跟那個供應商
  product_vendor_id bigint,
  constraint fk_product_vendor foreign key(product_vendor_id) references product_vendor(id),

  -- 這次捕獲是關於那個商品
  product_id  bigint,
  constraint fk_product foreign key(product_id) references product(id),

  -- 這次捕獲是關於那個商品方案
  model_id  bigint,
  constraint fk_model foreign key(model_id) references model(id)
);

/****************************************************************************************************
  購物車 - 商品
****************************************************************************************************/
create table cart_order (
  id           bigserial not null primary key,
  quantity     Integer not null,                -- 購買數量
  image_url    varchar(150) not null,           -- 商品照片 url
  product_url  varchar(150) not null,           -- 商品頁面 url
  unit_price   money not null,                  -- 商品單價     
  product_name varchar(50) not null,            -- 商品名稱
  model_name   varchar(50) not null,            -- 方案名稱

  create_time  timestamp not null default now(),
  update_time  timestamp,

  user_id bigint,
  constraint fk_user foreign key(user_id) references app_user(id),

  model_id bigint,
  constraint fk_model foreign key(model_id) references model(id)
);

/****************************************************************************************************
  願望清單 - 商品
****************************************************************************************************/
create table wishlist_item (
  id bigserial not null primary key,
  image_url    varchar(150) not null,           -- 商品照片 url
  product_url  varchar(150) not null,           -- 商品頁面 url
  unit_price   money not null,                  -- 商品單價     
  product_name varchar(50) not null,            -- 商品名稱
  model_name   varchar(50) not null,            -- 方案名稱

  create_time  timestamp not null default now(),
  update_time  timestamp,

  user_id bigint,
  constraint fk_user foreign key(user_id) references app_user(id),

  model_id bigint,
  constraint fk_model foreign key(model_id) references model(id)
);


COMMIT TRANSACTION;