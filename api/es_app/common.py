from ast import literal_eval
from datetime import datetime
from os import environ
from typing import Any, Callable, List


def get_var(env_var: str, default: Any = None) -> Any:
    """Scans environment locations for variable
    Checks in order:
        os.environ
        locals()
        globals()

    :param env_var: Name of variable for grabbing
    :param default: Value to return if variable not found
    :return: value of variable or default
    """
    if res := environ.get(env_var):
        return res
    if res := locals().get(env_var):
        return res
    if res := globals().get(env_var):
        return res
    return default


def eval_list(list_: str, element_type: Callable = str) -> List[Any]:
    """Converts list repr to active list using element_type to enforce
    the type of all elements present in list

    :param list_: list repr string
    :param element_type: function for asserting type (i.e. str, int, etc.)
    :return: list object containing elements of desired type
    """
    return list(map(element_type, literal_eval(list_)))


def pretty_time() -> str:
    return datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
