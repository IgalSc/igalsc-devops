SELECT * from report_dashboardcard
where dashboard_id = '549'


select * from report_card
where id = '786'

select * from report_card rc 
where dataset_query like '%"database":33%'

update report_card 
set database_id = '34'
where dataset_query like '%"database":33%'

UPDATE report_card
SET dataset_query = JSON_SET(dataset_query, '$.database', 34)
WHERE JSON_UNQUOTE(JSON_EXTRACT(dataset_query, '$.database')) = '33';