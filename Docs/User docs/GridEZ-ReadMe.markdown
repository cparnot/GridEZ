# GridEZ.framework

### Introduction

The GridEZ framework was written to make Xgrid integration in your application very easy. The XgridFoundation API is powerful, but complicated to use. To allow the user to connect to a Controller, submit a job and get the results back, you have to write hundreds of lines of code using the XgridFoundation, and manage a complex chain of asynchronous callbacks that XgridFoundation requires you to follow. The GridEZ framework provides easy-to-use objects that hide this complexity, and yet provide most of the functionality you need. For instance, when you submit a job, the results will be automatically loaded in your application when the job finishes and all is left to you is to write the delegate method to handle it. If you have never used the XgridFoundation APIs, you might wonder what the big deal is. But if you have, you probably already realize how GridEZ might make your life much much easier...

### Examples

To better see what you can do with GridEZ, the best place to start is in the Examples folder in the GridEZ distribution. The code used in these examples is released under the modified BSD license, so you can freely use it and modify it for your application. The PolyShell example is explained in greater detail in a [tutorial](GridEZ-Tutorial1.html).

* _PolyShell_: this is a very simple example application, with just one class, 8 methods, and ~30 lines of actual code; yet, it is already quite powerful; the user can connect to an Xgrid Controller, type a list of shell commands, and have PolyShell submit them all in one job, and browse the results when they are done
* _XgridCal_: a slightly more complex application, with 3 classes; the Scheduler class included in this project can be used in any application where you want to submit a bunch of independent tasks that can be run in any order on the grid (for instance, 3D rendering of the frames of an animation movie). Just provide a dataSource to provide the number of tasks, the task specifications and handle the results, and the Scheduler takes care of the rest. When all the tasks are done, the Scheduler delegate is notified.


### Features

* the XgridFoundation API is powerful, but complicated to use; the GridEZ framework provides easy-to-use objects that hide the complex chain of asynchronous callbacks that XgridFoundation requires you to follow:
	* GEZServer: easy-to-use wrapper for XGController/XGConnection
	* GEZJob: wrapper for XGJob; submission and result retrieval as it should be: submit a job and get the results in a delegate method
	* GEZGrid: for more advanced uses, you may need to occasionally specify a specific grid to submit jobs to (by default, submitting to a server will submit to the default grid)
* Bonjour browser: with just one call to the startBrowsing method, you get all the local Xgrid Controllers available to the user and ready to be used by your application
* Controller Connection Window: without writing any code, your application can let the user connect to any Xgrid Controllers she has access to using the prebuilt connection panel that handles local and remote connections, authentication,...; your application can then easily access these servers or be notified when the user connects to them
* integration with CoreData; with just one call to the save method, your application will automatically save all the information about the jobs it submitted and the server it connected to in the past; for instance, the user may quit your application and come back later to retrieve all the jobs that are now finished, and you don't have to write any code to provide that functionality



### Side effects

Because some users are sensitive to that issue, it is important for you to realize that when using the GridEZ.framework, your application will now create the following folder and add some files inside this location, in the user's folder:

* ~/Library/Application Support/_THE_NAME_OF_YOUR_APP_/GridEZ
* ~/Library/Application Support/GridEZ

This is where persistent information about the xgrid servers and jobs is stored.

The creation of these files can be disabled using appropriate keys in the Info.plist file of your application (see below section on Advanced Options). At present, it can't be disabled for standalone non-GUI tools.


### Adding GridEZ.framework to your Xcode project

The integration of GridEZ.framework into your application is similar to the use of any other framework. The following instructions are for Xcode 2.2. For a more detailed example, read the PolyShell [tutorial](GridEZ-Tutorial1.html).

To be able to compile your application and link it to the GridEZ framework, you should do the following:

* Copy GridEZ.framework to a location that Xcode can find, for instance ~/Library/Frameworks
* Select the menu Project ... Add to Project... and select the GridEZ.framework package in the file selection sheet
* In the next panel, make sure the check box for you target is selected
* In this same panel, you probably don't want to make a copy of it if it is already in ~/Library/Frameworks or a location Xcode can find
* Ideally, you want to place the GridEZ.framework item in the the 'Linked Frameworks' group in the 'Groups & Files' pane
* Add an <code>#import <GridEZ/GridEZ.h></code> where needed, for instance in your prefix header


The easiest way to have GridEZ.framework available at runtime is to embed it in your application (the binary of the framework was compiled with the installation path "@executable_path/../Frameworks"). To use it this way, you should add a copy phase to the target:

* If you have more than one target in your project, make sure you select the target of interest
* Select the menu Project ... New Build Phase ... New Copy Files Build Phase
* This will add an item in the 'Groups & Files' pane: Targets > YourTarget > CopyFiles
* The inspector panel for that 'Copy Files' item will open automatically, but you can always go back to it by selecting it the 'Groups & Files' pane, and selecting the menu File ... Get Info
* In this inspector panel, select Frameworks in the pop-up menu for Destination
* You can close the inspector panel
* In the 'Groups & Files' pane, drag the GridEZ.framework item into the newly created 'CopyFiles' group

Finally, you will usually want to link to the XgridFoundation.framework, installed by Apple in /System/Library/Frameworks. For convenience, the GridEZ header already #import the header, but you still have to explicity link to XgridFoundation if you use any of its symbols. In particular, you will probably want to use the keys defined by XgridFoundation to build the specification dictionary needed to submit a job.

Here are some relevant internet links with more details on linking/embedding frameworks:

* [Apple documentation](http://developer.apple.com/documentation/MacOSX/Conceptual/BPFrameworks/Tasks/CreatingFrameworks.html#//apple_ref/doc/uid/20002258-106880-BAJJBIEF)
* [CocoaDevCentral tutorial](http://www.cocoadevcentral.com/articles/000042.php) (somewhat outdated)



### Advanced options

Some options can be set by editing the Info.plist file of the application that uses the GridEZ.framework. Here is a list of the supported keys:

* GEZShouldUseUndoManager: by default, the default managed object context created by the framework will not have an NSUndoManager attached to it; you can force the addition of one using this key
* GEZStoreType: by default, the default managed object context created by the framework will create a store of type SQLLite; you can change this by setting the value of this key to one of these strings:
	* SQLite
	* XML
	* Binary
	* InMemory


For instance, you would add the following lines in the Info.plist file to add an NSUndoManager to the application-wide managedObjectContext and to use an XML store:

	<key>GEZShouldUseUndoManager</key>
	<string>YES</string>
	<key>GEZStoreType</key>
	<string>XML</string>
