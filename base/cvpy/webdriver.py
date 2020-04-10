#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
   This class is responsible for initiating a webdriver. If called by itself,
   it tests for example.com using both curl and chromedriver (currently).
"""
import logging
import requests
import traceback
import time
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

    """
    def __init__(self, url=None, driver='chromedriver', output='text',
                 options=['--no-sandbox', '--disable-logging',
                          '--disable-gpu', '--disable-dev-shm-usage',
                          'headless'],
                 service_args=['--ignore-ssl-errors=true',
                               '--ssl-protocol=any'], script=None,
                 timeout=30, implicit_wait=5, remote=True,
                 logger=logging.getLogger(ce('LOGGER', 'main'))):
        """
            initiate the WebDriver class
        """
        self.logger = logger
        self.url = url
        self.driver_type = driver
        self.output_type = output
        self.opts = options
        self.service_args = service_args
        self.out = None
        self.timeout = timeout
        self.driver = None
        if script is None:
            self.script = ''
        else:
            # if remote:
            #   self.driver
            self.script = script
        if driver.lower() in ['requests', 'curl']:
            self.out = self.request_url()
        elif driver.lower() == 'chromedriver':
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
            self.driver.set_window_size(1024, 768)
            self.logger.info('Connecting to %s' % self.url)
            self.driver.get(self.url)
            self.logger.info('Connected to %s' % self.url)

    def __str__(self):
        """ creates a simple string object """
        msg = 'WebDriver() Class with the following attributes:\n\tURL:'
        msg = msg + '%s\n\tDriver: %s\n' % (self.url, self.driver_type)
        if hasattr(self, driver) and self.driver is not None:
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
                    self.logger.warning(f'Unknown exception when deleting object: {e}')
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
            self.logger.error(f'An Error occurred while processing {self.url}: {e}')
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
        try:
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
                raise ParserError(f'{elem_type} is not a supported type')
        except KeyError as e:
            self.logger.error(f'KeyError thrown {e}')
        except WebDriverException as e:
            self.logger.error(f'WebDriver threw an exception {e}')
        except TimeoutException as e:
            self.logger.error(f'Timed out locating {elem}')
        except NoSuchElementException as e:
            msg = f'Element {elem} not found on page after '
            msg = msg + f'{wait} seconds: {e}'
            self.logger.error(msg)
            raise ParserError(msg)
        except Exception as e:
            self.logger.error(f'Unknown exception while waiting for element: {e}')

    def take_screenshot(self, output_file):
        """Take a screenshot of the screen."""
        self.logger.info(f'Sleeping for {self.timeout} seconds.')
        time.sleep(self.timeout)
        self.logger.info('Finished sleeping, taking screenshot and storing ' +
                         f'{output_file}')
        self.driver.save_screenshot(output_file)
        return output_file

    def page_down(self):
        """Simulate Page Down key in browser."""
        actions = ActionChains(self.driver)
        actions.send_keys(Keys.PAGE_DOWN)
        actions.perform()


if __name__ == "__main__":
    import time
    from bs4 import BeautifulSoup as Soup
    from selenium.webdriver.common.action_chains import ActionChains
    from selenium.webdriver.support.ui import Select
    test_url = 'http://www.example.com'
    print('Testing if requests work')
    with WebDriver(url=test_url, driver='curl') as d:
        source = d.dump_out()
    print(source)
    with WebDriver(url=test_url, driver='chromedriver',
                   options=['--no-sandbox', '--disable-gpu',
                            '--disable-logging',
                            '--disable-setuid-sandbox',
                            '--disable-dev-shm-usage',
                            '--no-zygote', 'headless'],
                   service_args=['--ignore-ssl-errors=true',
                                 '--ssl-protocol=any']) as d:
        source = d.driver.page_source
    print(source)
    print('Running example EI ID 182')
    url_182 = 'https://ebill.kcelectric.coop/woViewer/mapviewer.html?'
    url_182 = url_182 + 'config=Outage+Web+Map'
    chrome_opts = ['--no-sandbox', '--disable-gpu', '--disable-logging',
                   '--disable-setuid-sandbox', '--disable-dev-shm-usage',
                   '--no-zygote', 'headless']
    service_args = ['--ignore-ssl-errors=true', '--ssl-protocol=any']
    with WebDriver(url=url_182, driver='chromedriver',
                   options=chrome_opts,
                   service_args=service_args) as d:
        xpath = '//div[@id="OMS.Customers Summary"]'
        # d.wait_for_element(xpath, 'xpath')
        # arget = d.driver.find_element_by_xpath(xpath)
        target = d.get_xpath(xpath)
        ActionChains(d.driver).move_to_element(target).click(target).perform()
        d.wait_for_element('select', 'tag')
        select = Select(d.driver.find_element_by_tag_name('select'))
        time.sleep(2)
        select.select_by_visible_text('County')
        source = d.driver.page_source
    soup = Soup(source, 'html.parser')
    table = soup.findAll('table', {'class': 'GNBU0IVDGE summary-table'})
    rows = table[0].find_all('td')
    regions = []
    custs_out = []
    custs_served = []
    for row in rows:
        if 'summary-region-column' in str(row):
            regions.append(row.get_text().replace(" County", "").replace(
                                " COUNTY", "").strip().replace("ST ", "ST. "))
        elif 'summary-number-out-column' in str(row):
            custs_out.append(row.get_text())
        elif ('summary-number-served-column' in str(row) and
              "GMFGE5DLD" not in str(row) and "%" not in row.get_text()):
            custs_served.append(row.get_text())
        else:
            pass
    print('Regions found: %s' % regions)
    print('Customers out: %s' % custs_out)
    print('Custs served: %s' % custs_served)
