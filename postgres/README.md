## 指令

* 確定是否能夠連線到 node
> ansible all -i hosts -m ping -u root   

* 安裝 postgresql
> ansible-playbook -i hosts -u root build-postgresql.yml

* 取得自訂義分詞
> ansible-playbook -i hosts -u root fetch-custom-word.yml

* 餵自定義分詞
> ansible-playbook -i hosts -u root feed-custom-word.yml 

* 跑 sql
> ansible-playbook -i hosts -u root run-sql.yml

## postgres 指令

* 查看所有 trigger
> select trigger_schema, trigger_name, event_manipulation, action_statement from information_schema.triggers;


https://postindustria.com/postgresql-geo-queries-made-easy/


## Postgres 全文字搜索

> select to_tsvector('zhcfg','迪士尼公主系列') @@ to_tsquery('zhcfg','迪士尼');