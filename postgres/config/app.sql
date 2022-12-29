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


/***************************************************************************************************
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

/***************************************************************************************************
  作品
****************************************************************************************************/
create table work (
  id bigint not null primary key,
);

/***************************************************************************************************
  影音 (照片 or 影片)
****************************************************************************************************/
create table media {
  id          bigint not null primary key,
  url         varchar(150) not null,       -- 影音地址
  bucket      varchar(150) not null,       -- 影音目錄
  key         varchar(100) not null,       -- 影音名稱
  arrangement smallint default -1,         -- 排版順序 
  description varchar(150),    

  create_time  timestamp not null default now(),  
  update_time  timestamp,

  work_id bigint,
  constraint fk_work foreign key(work_id) references work(id)
}


COMMIT TRANSACTION;