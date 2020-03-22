# api

Python package and Docker setup for ElasticSearch REST api


## syntax
1. `/put/<uid>[?sep=,]` : Post operation identified by uid that expects
JSON data
    * JSON keys should represent column names
    * JSON values should be either lists or a string of comma-separated rows
    * If comma separation is sub-optimal, separator may be specified with
    `?sep=<separator_character>`