#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
   This class is responsible for initiating a webdriver. If called by itself,
   it tests for example.com using both curl and chromedriver (currently).
"""
import os
import time
import logging
import tempfile
import requests
import traceback
import shutil
import pandas as pd
from selenium import webdriver
from selenium.webdriver.remote.webdriver import WebDriver as WD
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support.select import Select
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import ElementNotVisibleException
from selenium.common.exceptions import NoSuchAttributeException
from selenium.common.exceptions import WebDriverException
from selenium.common.exceptions import NoSuchElementException
from selenium.common.exceptions import NoSuchFrameException
from selenium.common.exceptions import StaleElementReferenceException
from selenium.common.exceptions import NoSuchWindowException
from selenium.common.exceptions import ErrorInResponseException
from selenium.common.exceptions import TimeoutException
from urllib3.exceptions import HTTPError, ConnectionError
from datetime import datetime
from cvpy.common import check_environment as ce
from cvpy.exceptions import IngestException


class WebDriver():
    """
    this class is a wrapper for interacting with selenium's webdriver or
    requests

        :Details:
            chrome requires google chrome and chromedriver
            firefox requires geckodriver

        :param url the URL being requested
        :param driver the type of driver to use to connect
        :param output the type of output to request (requests driver only)
        :param options list of options to be passed to selenium
        :param service_args a list of service arguments to be passed to driver
        :param timeout how long to wait for an element to appear before timing
                       out
        :param implicit_wait set how long to wait on a DOM object
        :param logger the logger to log the logs
        :param container bool, should we use a chromedriver container
                         connection?

    """
    def __init__(self, url=None, driver='chromedriver', output='text',
                 options=['--no-sandbox', '--disable-logging',
                          '--disable-gpu', '--disable-dev-shm-usage',
                          'headless'],
                 additional_options=None, javascript=False,
                 service_args=['--ignore-ssl-errors=true',
                               '--ssl-protocol=any'], script=None,
                 window_height=1080, window_width=1920,
                 preferences = {},
                 timeout=30, implicit_wait=5, sleep_time = None,
                 logger=logging.getLogger(ce('LOGGER', 'main')),
                 container=False, remote='http://chrome:4444/wd/hub'):
        """
            initiate the WebDriver class
        """
        self.logger = logger
        self.url = url
        self.output_type = output
        self.opts = options
        if additional_options is not None:
            if isinstance(additional_options, str):
                self.opts.append(additional_options)
            elif isinstance(additional_options, list):
                self.opts.extend(additional_options)
            else:
                self.logger.error(
                    f'Unsupported additional argument: {additional_options}')
        self.service_args = service_args
        self.out = None
        self.timeout = timeout
        self.driver = None
        self.container = container
        self.remote = remote
        self.javascript = javascript
        self.preferences = preferences
        self.sleep_time = sleep_time
        self.logger.info(f'Connecting with driver: {driver}')
        if script is None:
            self.script = ''
        else:
            # if remote:
            #   self.driver
            self.script = script
        if driver.lower() in ['requests', 'curl']:
            self.out = self.request_url()
        elif driver.lower() == 'chromedriver' and container is False:
            self.request_chrome()
        elif driver.lower() == 'chromedriver' and container is True:
            self.request_chrome_hub()
        elif driver.lower() == 'phantomjs':
            self.request_phantomjs()
        elif driver.lower() == 'firefox':
            # handle firefox here
            pass
            self.request_chrome()
        elif driver.lower() == 'phantomjs':
            self.request_phantomjs()
        elif driver.lower() == 'firefox':
            # handle firefox here
            pass
        elif driver.lower() == 'opera':
            # handle opera here
            pass
        elif driver.lower() == 'ie':
            pass
        else:
            traceback.print_stack()
            raise KeyError('No driver type ' + driver)
        if hasattr(self, 'driver') and self.driver is not None:
            self.driver.implicitly_wait(implicit_wait)
            self.driver.set_window_size(window_width, window_height)
            self.logger.info('Connecting to %s' % self.url)
            self.driver.get(self.url)
            time.sleep(self.timeout)
            self.logger.info('Connected to %s' % self.url)

    def __str__(self):
        """Create a simple string object."""
        msg = 'WebDriver() Class with the following attributes:\n\tURL:'
        msg = msg + '%s\n\tDriver: %s\n' % (self.url, self.driver_type)
        if hasattr(self, 'driver') and self.driver is not None:
            msg = msg + '\nDriver has been initialized'
        return msg

    def __enter__(self):
        """ return self upon entry via with """
        return self

    def __exit__(self, wd_type, wd_value, wd_traceback):
        """ handle exiting the with """
        self.close()

    def __del__(self):
        """ delete the webDriver object """
        self.close()

    def close(self):
        """ close the webdriver class """
        if hasattr(self, 'driver'):
            if self.driver is not None:
                try:
                    self.driver.close()
                    self.driver.quit()
                except Exception as e:
                    self.logger.warning(
                        f'Unknown exception when deleting object: {e}')
                finally:
                    del self.driver
        del self

    def request_url(self):
        """ use requests to parse the url """
        try:
            response = requests.get(self.url, timeout=10)
            response.raise_for_status()
        except ConnectionError as e:
            self.logger.error(f'Connection error occurred: {e}')
        except HTTPError as e:
            self.logger.error(f'HTTP error occurred: {e}')
        except Exception as e:
            self.logger.error(
                f'An Error occurred while processing {self.url}: {e}')
        if self.output_type == 'text':
            return response.text
        if self.output_type == 'json':
            return response.json()
        self.logger.error(f'Unknown output_type specified: {self.output_type}')
        self.logger.error('Returning bare response')
        return response

    def request_remote(self):
        self.options = webdriver.ChromeOptions()
        try:
            if self.opts is not None:
                for opt in self.opts:
                    self.options.add_argument(opt)
                self.driver = WD(
                    'chrome:4444/wd/hub',
                    desired_capabilities={'browserName': 'chrome'},
                    options=self.options)
        except WebDriverException as e:
            self.logger.error(f'Webdriver threw an exception {e}')
        except Exception as e:
            self.logger.error(f'Webdriver threw an exception {e}')

    def request_chrome(self):
        """ method to create driver based on chrome """
        self.logger.info(f'Using chrome to connect to {self.url}')
        self.options = webdriver.ChromeOptions()
        if self.javascript:
            self.options.add_argument("javascript.enabled", True)
        try:
            if isinstance(self.preferences, dict):
                tmp_dir_name = tempfile.TemporaryDirectory().name
                self.preferences["download.default_directory"] = tmp_dir_name
                self.options.add_experimental_option("prefs",
                                                     self.preferences)
                self.logger.info(f'Temporary directory {tmp_dir_name}')
            if self.opts is not None:
                for opt in self.opts:
                    self.options.add_argument(opt)
                if self.service_args is None:
                    self.driver = webdriver.Chrome(self.driver_type,
                                                   options=self.options)
                else:
                    self.driver = \
                        webdriver.Chrome(self.driver_type,
                                         service_args=self.service_args,
                                         options=self.options)
            else:
                if self.service_args is None:
                    self.driver = webdriver.Chrome(self.driver_type)
                else:
                    self.driver = \
                        webdriver.Chrome(self.driver_type,
                                         service_args=self.service_args)
        except WebDriverException as e:
            self.logger.error(f'Webdriver Exception thrown: {e}')
        except Exception as e:
            self.logger.error(f'Unknown exception while creating driver  {e}')

    def request_chrome_hub(self):
        self.logger.info(f'Using chrome to connect to {self.remote}')
        self.options = webdriver.ChromeOptions()
        try:
            if self.opts is not None:
                for opt in self.opts:
                    self.options.add_argument(opt)
                if self.service_args is None:
                    self.driver = webdriver.Remote(
                        command_executor=self.remote,
                        desired_capabilities=DesiredCapabilites.CHROME,
                        options=self.options)
                else:
                    self.driver = \
                        webdriver.Chrome(self.remote,
                                         service_args=self.service_args,
                                         options=self.options)
            else:
                if self.service_args is None:
                    self.driver = webdriver.Remote(self.remote)
                else:
                    self.driver = \
                        webdriver.Chrome(self.remote,
                                         service_args=self.service_args)
        except WebDriverException as e:
            self.logger.error(f'Webdriver Exception thrown: {e}')
        except Exception as e:
            self.logger.error(f'Unknown exception while creating driver  {e}')

    def get_xpath(self, xpath):
        self.wait_for_element(xpath, 'xpath')
        try:
            target = self.driver.find_element_by_xpath(xpath)
            return target
        except NoSuchElementException as e:
            self.logger.error(f'Unable to find xpath "{xpath}": {e}')
        except WebDriverException as e:
            self.logger.error(f'Webdriver error occurred: {e}')
        except StaleElementReferenceException as e:
            self.logger.error(f'Element seems stale: {e}')

    def get_tag(self, tag):
        self.wait_for_element(tag, 'tag')
        try:
            target = self.driver.find_element_by_tag_name(tag)
            return target
        except NoSuchElementException as e:
            self.logger.error(f'The tag {tag} does not exist: {e}')
        except WebDriverException as e:
            self.logger.error(f'Webdriver error occurred: {e}')
        except StaleElementReferenceException as e:
            self.logger.error(f'Element seems stale: {e}')

    def get_id(self, id_name):
        self.wait_for_element(id_name, 'id')
        try:
            target = self.driver.find_element_by_id(id_name)
            return target
        except NoSuchElementException as e:
            self.logger.error(f'The tag {id_name} does not exist: {e}')
        except WebDriverException as e:
            self.logger.error(f'Webdriver error occurred: {e}')
        except StaleElementReferenceException as e:
            self.logger.error(f'Element seems stale: {e}')

    def get_class(self, class_name):
        self.wait_for_element(class_name, 'class')
        try:
            target = self.driver.find_element_by_class_name(class_name)
            return target
        except NoSuchElementException as e:
            self.logger.error(f'The class {class_name} does not exist: {e}')
        except WebDriverException as e:
            self.logger.error(f'Webdriver error occurred: {e}')
        except StaleElementReferenceException as e:
            self.logger.error(f'Element seems stale: {e}')

    def move_to_element(self, target):
        """ perform action chains move to element and click """
        try:
            action_chains = ActionChains(self.driver).move_to_element(target)
            action_chains.click(target).perform()
        except NoSuchElementException as e:
            self.logger.error(f'The element {target} does not exist: {e}')
        except TimeoutException as e:
            self.logger.error(f'Connection timed out: {self.url}')
        except WebDriverException as e:
            self.logger.error('Webdriver error occurred: {e}')
        except StaleElementReferenceException as e:
            self.logger.error(f'Element seems stale: {e}')

    def request_phantomjs(self):
        """ method to create driver based on PhantomJS """
        self.driver = webdriver.PhantomJS(service_args=self.service_args)

    def dump_out(self):
        """ dump self.out attribute """
        return self.out

    def driver_out(self):
        """ dump self.driver attribute """
        return self.driver

    def wait_for_element(self, elem, elem_type, wait=None):
        """Wait until element is available in the page."""
        if wait is None:
            wait = self.timeout
        self.logger.info(f'Waiting {wait} seconds for {elem_type} ' +
                         f'with value of {elem}.')
        try:
            if elem_type.lower() == 'xpath':
                element_present = EC.presence_of_element_located((By.XPATH,
                                                                  elem))
                WebDriverWait(self.driver, wait).until(element_present)
            elif elem_type.lower() == 'id':
                element_present = EC.presence_of_element_located((By.ID,
                                                                  elem))
                WebDriverWait(self.driver, wait).until(element_present)
            elif elem_type.lower() == 'class':
                element_present = EC.presence_of_element_located((
                    By.CLASS_NAME, elem))
                WebDriverWait(self.driver, wait).until(element_present)
            elif elem_type.lower() == 'css':
                element_present = EC.presence_of_element_located((
                    By.CSS_SELECTOR, elem))
                WebDriverWait(self.driver, wait).until(element_present)
            elif elem_type.lower() == 'name':
                element_present = EC.presence_of_element_located((
                    By.NAME, elem))
                WebDriverWait(self.driver, wait).until(element_present)
            elif elem_type.lower() == 'tag':
                element_present = EC.presence_of_element_located((
                    By.TAG_NAME, elem))
                WebDriverWait(self.driver, wait).until(element_present)
            elif elem_type.lower() == 'link text':
                element_present = EC.presence_of_element_located((
                    By.LINK_TEXT, elem))
                WebDriverWait(self.driver, wait).until(element_present)
            elif elem_type.lower() == 'partial link text':
                element_present = EC.presence_of_element_located((
                    By.PARTIAL_LINK_TEXT, elem))
                WebDriverWait(self.driver, wait).until(element_present)
            else:
                raise IngestException(f'{elem_type} is not a supported type')
        except KeyError as e:
            self.logger.error(f'KeyError thrown {e}')
        except WebDriverException as e:
            self.logger.error(f'WebDriver threw an exception {e}')
        except TimeoutException as e:
            self.logger.error(f'Timed out locating {elem}: {e}')
        except NoSuchElementException as e:
            msg = f'Element {elem} not found on page after '
            msg = msg + f'{wait} seconds: {e}'
            self.logger.error(msg)
            raise IngestException(msg)
        except Exception as e:
            self.logger.error(
                f'Unknown exception while waiting for element: {e}')

    def take_screenshot(self, output_file):
        """Take a screenshot of the screen."""
        self.logger.info(f'Sleeping for {self.timeout} seconds.')
        time.sleep(self.timeout)
        self.logger.info('Finished sleeping, taking screenshot and storing ' +
                         f'{output_file}')
        self.driver.save_screenshot(output_file)
        return output_file

    def page_down(self, elem):
        """Send page down key."""
        self.logger.info('Simulating Page Down key press')
        actions = ActionChains(elem)
        actions.send_keys(Keys.PAGE_DOWN)

    def get_images(self):
        """Retrieve all images in a web page."""
        self.logger.info(f'Retrieving all images from {self.url}')
        imgs = self.driver.find_elements_by_tag_name('img')
        img_srcs = list()
        for i in imgs:
            img_srcs.append(i.get_attribute('src'))
        self.logger.info(f'Found {len(img_srcs)} images.')
        return img_srcs

    def get_image(self, xpath=None, tag=None, id_name=None,
                  class_name=None):
        """Retrieve an image in a web page."""
        if xpath is None and tag is None and id_name is None and \
                class_name is None:
            raise IngestException('Webdriver.get_image() requires one of ' +
                                  'xpath|tag|id_name|class_name.')
        if xpath is not None:
            img = self.get_xpath(xpath)
        elif tag is not None:
            img = self.get_tag(tag)
        elif id_name is not None:
            img = self.get_id(id_name)
        elif class_name is not None:
            img = self.get_class(class_name)
        else:
            raise IngestException('Bad logic passed to WebDriver.get_image()')
        return img.get_attribute('src')

    def get_csv(self):
        temp_dir = self.preferences['download.default_directory']
        file_list = os.listdir(temp_dir)
        if len(file_list) == 1:
            df = pd.read_csv(self.preferences['download.default_directory']+
                             '/'+file_list[0])
        shutil.rmtree(temp_dir)
        return df


if __name__ == "__main__":
    # TODO add tests here
    pass
