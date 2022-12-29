BEGIN TRANSACTION;

/****************************************************************************************************
    earthdistance: 做 geo location 用的 extensions
****************************************************************************************************/
alter user postgres password '6705Brian';

CREATE EXTENSION earthdistance CASCADE;

CREATE EXTENSION zhparser;
CREATE TEXT SEARCH CONFIGURATION zhcfg (PARSER = zhparser);
ALTER TEXT SEARCH CONFIGURATION zhcfg ADD MAPPING FOR a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z WITH simple;

SET TIMEZONE='Asia/Taipei';

create type day_of_week as enum('sunday','monday','tuesday','wednesday','thursday','friday','saturday');
create type permission as enum('owner','manager', 'employee');

/****************************************************************************************************
    國家碼
****************************************************************************************************/
create table callingcode (
    id                  bigserial   not null primary key,
    chinese_name        varchar(50) not null,
    english_name        varchar(50) not null,
    code                varchar(10) not null,
    create_time         timestamp   default now(),
    update_time         timestamp   default null
);

insert into callingcode (chinese_name,english_name,code) values ('台灣','Taiwan','+886');
insert into callingcode (chinese_name,english_name,code) values ('美國','Unitde State','+1');


/****************************************************************************************************
    公司
****************************************************************************************************/
create table company (
    id                  bigint not null primary key,
    name                varchar(50) not null,
    latitude            double precision,
    longitude           double precision,
    formatted_address   varchar(150),
    valid_punch_distance  float default 100,

    create_time         timestamp   default now(),
    update_time         timestamp   default null
);

-- 距離搜尋 index
create index company_location_idx on company using gist(ll_to_earth(latitude, longitude));

-- 文字搜尋 index
alter table company 
add column ts tsvector 
generated always as (to_tsvector('zhcfg',coalesce(name,''))) stored;
create index company_name_idx on company using GIN(ts);


/****************************************************************************************************
    部門
****************************************************************************************************/
create table department (
  id                    bigserial not null primary key,
  name                  varchar(50) not null,
  latitude              double precision,
  longitude             double precision,
  formatted_address     varchar(150),
  valid_punch_distance  float default 100,
  week_end              day_of_week[],

  create_time         timestamp   default now(),
  update_time         timestamp   default null,

  company_id            bigint, 
  constraint fk_company foreign key(company_id) references company(id)
);

-- 距離搜尋 index
create index department_location_idx on department using gist(ll_to_earth(latitude, longitude));


/****************************************************************************************************
  假日
****************************************************************************************************/
create table holiday(
  id  bigserial not null primary key,
  day date not null,
  description varchar(50) not null default 'n/a'
);

insert into holiday (day, description) values (date'2022-01-01', '中華民國開國紀念日');
insert into holiday (day, description) values (date'2022-01-31', '農曆除夕');
insert into holiday (day, description) values (date'2022-02-01', '春節');
insert into holiday (day, description) values (date'2022-02-02', '春節');
insert into holiday (day, description) values (date'2022-02-03', '春節');
insert into holiday (day, description) values (date'2022-02-04', '彈性放假');
insert into holiday (day, description) values (date'2022-02-28', '和平紀念日');
insert into holiday (day, description) values (date'2022-04-04', '兒童節');
insert into holiday (day, description) values (date'2022-04-05', '民族掃墓節');
insert into holiday (day, description) values (date'2022-06-03', '端午節');
insert into holiday (day, description) values (date'2022-09-10', '中秋節');
insert into holiday (day, description) values (date'2022-10-10', '國慶日');

/****************************************************************************************************
  補班日
****************************************************************************************************/
create table make_up_day(
  id          bigserial not null primary key,
  day         date not null,
  description varchar(50) not null default 'n/a'
);

/****************************************************************************************************
  補班日
****************************************************************************************************/
create table exception_day(
  id          bigserial not null primary key,
  day         date not null,
  description varchar(50) not null default 'n/a',
  work        boolean,

  department_id bigint,
  constraint fk_department foreign key(department_id) references department(id)
);


/****************************************************************************************************
    輪班資訊
****************************************************************************************************/
create table shift(
  id bigserial not null primary key,
  name varchar(50) not null default '白班',
  start_time time without time zone,
  end_time time without time zone,

  create_time         timestamp   default now(),
  update_time         timestamp   default null,

  department_id bigint, 
  constraint fk_department_id foreign key(department_id) references department(id)
);


/****************************************************************************************************
    會員
****************************************************************************************************/
create table app_user (
    id                        bigint not null primary key,
    name                      varchar(50) not null default 'n\a',
    boarding_time             date,
    email                     varchar(50) not null unique,
    phone                     varchar(50),
    calling_code              varchar(10),
    email_confirmed           boolean not null default false,
    phone_confirmed           boolean not null default false,
    hash_password             varchar(150) not null,
    salt                      varchar(150) not null,
    work_on                   boolean not null default false,
    avatar                    varchar(150),
    securitystamp             varchar(150) not null,
    refresh_token             varchar(150) default null,
    refresh_token_expiry_time timestamp default null,
    permission                permission, 
    title                     varchar(50) default '成員',

    create_time               timestamp   default now(),
    update_time               timestamp   default null,

    -- 表示使用者是屬於哪一個部門的
    department_id bigint, 
    constraint fk_department foreign key(department_id) references department(id),

    -- 表示屬於哪一個公司的管理者
    company_id bigint,
    constraint fk_company foreign key(company_id) references company(id),

    -- 表示屬於哪個班表的
    shift_id bigint,
    constraint fk_shift foreign key(shift_id) references shift(id),

    -- 主管 
    manager_id bigint, 
    constraint fk_manager foreign key(manager_id) references app_user(id)
    
);

/****************************************************************************************************
    使用者登入資訊
****************************************************************************************************/
create table app_user_login (
  id                  bigserial not null primary key,
  device_type         varchar(50) default 'n\a',
  device_token        varchar(50) default null,

  create_time         timestamp   default now(),
  update_time         timestamp   default null,

  app_user_id bigint not null,
  constraint fk_app_user foreign key(app_user_id) references app_user(id)
);

/****************************************************************************************************
    打卡 - 紀錄
****************************************************************************************************/
create table punch (
    id                      bigserial not null primary key,
    action_time             timestamp not null default now(),
    latitude                double precision default 0.0,
    longitude               double precision default 0.0,
    distance                numeric(19,2) default 0.0,
    work_on                 boolean,

    create_time             timestamp   default now(),
    update_time             timestamp   default null,

    app_user_id              bigint not null,
    constraint fk_app_user   foreign key(app_user_id) references app_user(id)
); 


/****************************************************************************************************
    請假 - 紀錄
      sick: 病假
      personal: 事假
      paid: 特休
****************************************************************************************************/
create table leave (
    id                       bigserial not null primary key,
    leave_type               varchar(20) check (leave_type = any('{sick,personal,paid}'::text[])) default 'paid',
    reason                   varchar(300) not null,
    start_time               timestamp not null,
    end_time                 timestamp not null,
    prove                    boolean default null,

    create_time              timestamp   default now(),
    update_time              timestamp   default null,

    app_user_id              bigint not null,
    department_id            bigint not null,

    constraint fk_app_user   foreign key(app_user_id) references app_user(id),
    constraint fk_department foreign key(department_id) references department(id)
);


COMMIT TRANSACTION;