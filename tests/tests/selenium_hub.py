#!/usr/bin/env python3
from selenium import webdriver
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
driver = webdriver.Remote('http://hub:4444/wd/hub',
                          desired_capabilities=DesiredCapabilities.CHROME)
print(driver)
