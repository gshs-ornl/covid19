# api

Python package and Docker setup for ElasticSearch REST api


## syntax
1. `/put/<uid>` : Post operation identified by uid that expects
JSON data
    * Expects list of json objects containing information for post
    * As little conversion as possible is performed to maintain source data
    * If a lat and lon are present, they are replaced with a Point
    geometry and fips information is added from
    geo.fcc.gov/api/census/block/find
2. `/test-put/<uid>` : Post operation identified by uid that expects and
returns JSON data
