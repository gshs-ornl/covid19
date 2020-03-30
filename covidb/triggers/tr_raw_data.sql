/*
 if the county field is empty, assume it is state level, state will always be populated; if state_level is not provided
 (e.g. all counties), we need to sum and put those into the state table


--Update pages (move to setup.sql)
ALTER TABLE scraping.state_data
    ADD CONSTRAINT const_state_page_id
        UNIQUE (page_id);

ALTER TABLE scraping.county_data
    ADD CONSTRAINT const_county_page_id
        UNIQUE (page_id);

 -- Add page_id, state_id unique contraint

 */


DROP TRIGGER IF EXISTS tr_raw_data on scraping.raw_data;
CREATE TRIGGER tr_raw_data
    AFTER INSERT
    ON scraping.raw_data
    FOR EACH ROW
EXECUTE PROCEDURE scraping.fn_update_scraping();


--Update county trigger
/*
INSERT INTO customers (NAME, email)
VALUES
  (
     'Microsoft',
     'hotline@microsoft.com'
  )
ON CONFLICT ON CONSTRAINT customers_name_key
DO NOTHING;
*/

