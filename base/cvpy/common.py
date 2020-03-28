#!/usr/bin/env python3
""" contains common functions used throughout the cvpy package """


def check_environment(env_var, default=None):
    """ check if an environmental variable or variable is set, and if so,
        return that value, else return the default variable

        :param env_var the environmental variable to look for
        :param default the default value if the environmental variable is not
                       found
        :return returns either the value in the environmental variable or the
                        default value passed to this function (default of None)
    """
    if env_var in os.environ:
        return os.environ[env_var]
    if env_var in locals():
        return locals()[env_var]
    if env_var in globals():
        return globals()[env_var]
    return default
