from datetime import datetime
from os import environ
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
