set sql dialect 3;
update tests set "DATE"='01.01.80' where "DATE"<'01.01.80';
commit;
exit;
