#!/usr/bin/env python3
"""Helper functions when working with Responses from the Requests library"""
from requests import Response
from datetime import datetime

def determine_updated_timestep(response: Response) -> datetime:
    """
    Call this function ONLY if the website did not have a 'Last Modified' property in the HTML or JSON which could be scraped. 
    It may be preferable to use this value over a scraped value, since these values are guaranteed to be in GMT.

    This functionality will first try to check for a 'Last-Modified' HTTP Header in the request, and use it as the value to be stored in the database.
    A Last-Modifed header will always be in the following format: Thu, 06 Feb 2020 02:07:08 GMT 
    If this header does not exist, return None.

    :param response: The object retrieved from calling requests.get() in a scraper
    :type response: requests.Response
    :return the timestep from the Last-Modified HTTP Header if it exists, or None otherwise.
    :rtype datetime 
    """
    try:
        header_value = response.headers['last-modified']
        return datetime.strptime(header_value, "%a, %d %b %Y %H:%M:%S GMT")
    except KeyError:
        # header does not exist
        return None
        # return datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    except ValueError:
        # header is somehow in an invalid format - shouldn't be possible, but just in case...
        return None
        # return datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")