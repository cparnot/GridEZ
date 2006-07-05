To test the framework, I added more targets to the project, each testing different stages of developement. This is not unit testing or any kind of formal testing. To be useful, those tests need to be run in different conditions.

# General remarks  about test targets

* Keep code for each in separate folders

* When compiled in Debug configuration, these executables will print a lot of messages to the sdterr stream, which will help follow the different events and asynchronous calls, and might help find where a problem occured.


# TestServerHook

testing just the ServerHook and GridHook classes; it is a command-line tool, where you have to change the values for the server and password in the code; look at the TestServerHook implementation.


# Xgrid Controllers

GUI test application to test:

* the GEZServer and GEZGrid class
* the "Xgrid Controllers" window that can be used by any application; one should test Bonjour and remote hosts, with and w/o password, and then see what happens when password is wrong, and if "Cancel" works as expected, and if the displayed states are consistent
* the Grids window should also be consistent with what Xgrid Admin would show, in particular updating the name of a grid


# PolyShell

GUI application to test simple job submission.