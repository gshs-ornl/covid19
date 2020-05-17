#!/usr/bin/env python3
"""Tests that the remote webdriver works."""
import unittest
from selenium import webdriver
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from cvpy.webdriver import WebDriver as WB


class LocalGoogleTestCase(unittest.TestCase):

    def setUp(self):
        self.browser = webdriver.Chrome()
        self.addCleanup(self.browser.quit)

    def testPageTitle(self):
        self.browser.get('https://www.google.com')
        self.assertIn('Google', self.browser.title)


class RemoteGoogleTestCase(unittest.TestCase):

    def setUp(self):
        self.browser = webdriver.Remote(
            command_executor='http://chrome:4444/wd/hub',
            desired_capabilities=DesiredCapabilities.CHROME)
        self.addCleanup(self.browser.quit)

    def testPageTitle(self):
        self.browser.get('https://www.google.com')
        self.assertIn('Google', self.browser.title)


if __name__ == '__main__':
    unittest.main(verbosity=2)
