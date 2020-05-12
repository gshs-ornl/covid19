#!/usr/bin/env python3
"""Tests that the remote webdriver works."""
import logging
import unittest
from selenium import webdriver
from selenium.webdriver.support.expected_conditions import presence_of_element_located
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from cvpy.webdriver import WebDriver as WB

# logging.info('Connecting to remote')
# try:
    # driver = webdriver.Remote(command_executor='http://127.0.0.1:4444/wd/hub/',
                              # desired_capabilities=DesiredCapabilities.CHROME)
    # print(driver)
    # driver.get('https://www.google.com')
    # driver.quit()
    # logging.info('Remote connection successful!')
# except Exception as e:
    # logging.warning(f'Exception {e} raised.')
# logging.info("Testing if CVPY's image works.")

# try:
    # with WB(url='https://www.google.com', container=True) as wb:
        # wb.driver.get('https://www.google.com')
        # wb.driver.find_element(By.NAME, "q").send_keys("cheese" + Keys.RETURN)
        # first_result = wait.until(presence_of_element_located((BY.CSS_SELECTOR,
                                                            # "h3>div")))
        # print(first_result.get_attribute("textContent"))
# except Exception as e:
    # logging.warning(f'Exception {e} raised.')

class LocalGoogleTestCase(unittest.TestCase):

    def setUp(self):
        self.browser = webdriver.Chrome()
        self.addCleanup(self.browser.quit)

    def testPageTitle(self):
        self.browser.get('http://www.google.com')
        self.assertIn('Google', self.browser.title)


class RemoteNameGoogleTestCase(unittest.TestCase):

    def setUp(self):
        self.browser = WD('http://www.google.com',
                          container=True,
                          remote='http://chrome:4444/wd/hub')
        self.addCleanup(self.browser.quit())

    def testPageTitle(self):
        self.browser.driver.get('http://www.google.com')
        self.assertIn('Google', self.browser.title)

    class RemoteURLGoogleTestCase(unittest.TestCase):
    def setUp(self):
        self.browser = WD('http://www.google.com',
                          container=True,
                          remote='http://127.0.01:4444/wd/hub')
        self.addCleanup(self.browser.quit())

    def testPageTitle(self):
        self.browser.driver.get('http://www.google.com')
        self.assertIn('Google', self.browser.title)


if __name__ == '__main__':
    unittest.main(verbosity=2)
