from datetime import datetime
from os import environ
from typing import Any, Callable, List


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
    def getter(gettable: Any, default: Any = None) -> Any:
        tmp = gettable.get(key)
        if tmp is None:
            return default
        if methods:
            for func in methods:
                tmp = func(tmp)
        return tmp
    return getter
