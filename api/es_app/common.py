from datetime import datetime
from functools import wraps
from os import environ
from time import sleep
from typing import Any, Callable


def get_var(env_var: str, default: Any = None) -> Any:
    """Scans environment locations for variable

    :param env_var: Name of environment variable for grabbing
    :param default: Value to return if variable not found
    :return: value of variable or default
    """
    res = environ.get(env_var)
    if res is not None:
        return res
    return default


def pretty_time() -> str:
    return datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')


def identity(item: Any) -> Any:
    return item


def make_getter(key: str, *methods: Callable) -> Any:
    """Creates getter function to operate on gettable object

    The getter function created packages together the key to be
    used and the functions that should be used to transform the
    value before returning the value. Functions provided to methods
    will be conducted in order, so
    make_getter(key, a, b, c)
    would make a getter that would act as
    c(b(a(gettable.get(key))))

    :param key: key to be targeted in gettable
    :param methods: functions to apply to value before returning
    :return: getter function
    """
    def getter(gettable: Any, default: Any = None) -> Any:
        """Uses get method of gettable and applies methods

        :param gettable: object with get method (default not required)
        :param default: returned value if gettable.get(key) is None
        :return: retrieved and operated value or default
        """
        tmp = gettable.get(key)
        if tmp is None:
            return default
        if methods:
            for func in methods:
                tmp = func(tmp)
        return tmp
    return getter


class Backoff:
    """Wrapper class for adding exponential back-off to a
    function that is failing due to external circumstances.

    While it could be used for any exception, code guaranteed
    to fail will just use up the entire back-off duration

    Example
        @Backoff(TimeoutError, TransportError, etc)
        def some_api_call():
            ...

    """
    def __init__(self,
                 *exceptions: Exception,
                 start: float = 0.5,
                 factor: float = 2.0,
                 max_attempts: int = 5):
        if factor <= 1.0:
            raise ValueError("factor must be greater than 1.0")
        self.factor = factor
        self.start = start
        self.max_attempts = max_attempts
        self.exceptions = tuple(exceptions)

    def __call__(self, function: Callable) -> Callable:
        @wraps(function)
        def retry_with_backoff(*args: Any, **kwargs: Any) -> Any:
            for attempts in range(self.max_attempts):
                try:
                    return function(*args, **kwargs)
                except self.exceptions:
                    if attempts == (self.max_attempts - 1):
                        raise
                    sleep(self.start * pow(self.factor, attempts))
            raise Exception('How did you get here?')
        return retry_with_backoff
