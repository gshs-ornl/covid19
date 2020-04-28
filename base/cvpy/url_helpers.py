#!/usr/bin/env python3
"""Helper functions when working with Responses from the Requests library"""
import requests
import datetime

def determine_timestep(response: requests.Response) -> datetime.datetime:
    """
    Call this function ONLY if the website did not have a 'Last Modified' property in the HTML or JSON which could be scraped. 

    This functionality will first try to check for a 'Last-Modified' HTTP Header in the request, and use it as the value to be stored in the database.
    A Last-Modifed header will always be in the following format: Thu, 06 Feb 2020 02:07:08 GMT 
    If this header does not exist, generate a datetime based on the moment the request was accessed.

    :param response: The object retrieved from calling requests.get() in a scraper
    :type response: requests.Response
    :return the timestep from the Last-Modified HTTP Header if it exists, or a new timestep otherwise.
    :rtype datetime 
    """
    try:
        header_value = response.headers['last-modified']
        return datetime.datetime.strptime(header_value, "%a, %d %b %Y %H:%M:%S GMT")
    except KeyError:
        # It is important to use UTC time to be consistent with Last-Modified times
        # currently stripping nanoseconds for consistent formatting
        return datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")