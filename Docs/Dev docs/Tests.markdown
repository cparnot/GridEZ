Tests to perform on the GridEZ framework. Maybe in the future, something more systematic could be implemented, using the usual test suites. However, it is a bit complicated, with all the asynchronous callbacks.


# Manual tests

One way to test the framework is manually using the GUI of the example PolyShell:

## Servers
* Connection to server w/o password
* Stop the server while the app is running:
	* should become "Offline"
	* restart the server
	* should become "Available"
* Cannot delete Available/Connected servers
* Can delete Offline servers
* Connection to server with password, local/Bonjour and remote
* Connection to server with Kerberos single sign-on : NEVER TESTED!!


## Grids
* remove grids while running
* add grids while running
* change name of the grid while running


## Jobs
* submission --> do we get the results?
* submission and immediate deletion
* deletion --> gone from the server? gone from the store?
* submission to offline grids --> does it get automatically submitted after the server is connected?
* submit, then disconnect, then reconnect --> results are downloaded?
* submit, then disconnect, then delete, then reconnect --> results are downloaded? the job is deleted automatically after reconnection?


