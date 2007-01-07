Random quick notes on different aspects of the framework implementation. As these notes grow, the contents will be moved to separate files and organized better.

# Documentation

Notes written using the Markdown syntax. Maybe I will create a script to create the html automatically at some point. For now, I don't care. You can add link with Markdown. Keep a flat structure (no subdirs). File names will preferably not not have spaces, which might make it easier to generate html

* Dev docs = documentation for the developer of the framework; for instance, this file

* User docs = documentation for the user of the framework (who is also a developer, but not of the GridEZ framework...)



# Server and Grid creations:

the implementation makes sure that only one instance per server or per grid is created, at the lever of server/grid connections, and at the level of persistent servers/grids. This should be the case as long as only the public methods of each class are called from other classes, and following this rule:

* The server implementation is in charge of getting it right, by providing a convenience method 'gridWith...', that checks its array of grids to see if there is already a grid corresponding to the criteria, and returning nil if there is none; the implementation does NOT call the grid factory method
* The grid class implements a factory method that calls the server convenience method; only if the server returns a nil instance, can the grid assume the object does not exist yet, and can then create it
* The problem of this implementation is that it only superficially keeps things encapsulated; but that only works because I know what each method does and which ones decides; otherwise, if they both call each other, we get an infinite call stack building up
* In the future, I should come up with something better, maybe


# DEBUG flag

* The DEBUG flag is set in the settings for the "Debug" configuration, using the "Preprocessor Macros" flag (in the "Preprocessing" collection). This setting will result in "#ifdef DEBUG" to be true, and will trigger compilation of additonal code. The setting is not on for the "Release" configuration, of course

* One function dependent on DEBUG is the DLog function:

		void DLog(NSString *identifier, int level, NSString *fmt,...);

It is simply a NSLog wrapper that adds 2 parameters: an identifier string and a verbose level. The verbose threshold can be set globally using the "DebugLogVerboseLevel" key in the user defaults, and a list of keywords triggering the logging can be set globally in an NSArray defined by the "DebugIdentifiers" key in the user defaults. If not set by NSUserDefaults, these settings are ignored and the message is always printed. In most of the code, I use [self class] as the identifier. This allows to only print messages for selected classes.

* Another item dependent on the DEBUG flag is the name of the persistent store. A suffix "_DEBUG" is added to the name, to avoid messing up with any legitimate store setup using a 'Release' version of the program.


# Notes on Xgrid behavior regarding inputFiles and inputFileMap

* Bug with 10.4.1 and earlier:
	* you cannot have different sets of paths for different tasks, because the key XGJobSpecificationInputFileMapKey does not behave as expected; using this key in the task specifications cancel all uploads otherwise defined by the XGJobSpecificationInputFilesKey;
	* bug submitted by Charles Parnot
	* bug fixed in 10.4.2 (yeah!!) and tested again, it works as expected with the following behavior explained below...

* How inputFiles and inputFileMap work:
	* inputFiles is defined at the job level, and lists files as a Dictionary:
		* the key = a symbolic name (the same file can be reused for different tasks and given a different path for each task)
		* the value = a dictionary with 2 entries, fileData and isExecutable
	* inputFileMap is optionally defined at the task level and lists files to upload as a dictionary:
		* the key = the final path on the working directory of the agent
		* the value = the symbolic name used in the inputFiles

* About the executables dir and the command:
	* When inputFiles = one executable, and no inputFileMap in the task description, the file is named according to inputFile, and is both in ../executables and in ../working
	* Same result when inputFileMap is used and the final name in inputFileMap is the same as the name in inputFile
	* Same result when inputFileMap is used and the final name in inputFileMap is different from the name in inputFile
	* Same situation as above with 2 files in inputFileMap, including the executable: only the name used as the executable in the command string is used
	* If an executable is listed in inputFiles and in inputFileMap, but not used as the command, it is not put in the 'executables' directory but is still in the working directory ––> the workaround is to use as a command string "../working/executable"
	* If an executable is put in a directory in inputFileMap (or in inputFIles when no inputFileMap is provided), same result too
	* Conclusions:
		* the path to the executables dir is appended if the command string is a relative path
		* only one file can be added to the executables dir, and will be added if listed in inputFiles or inputFileMap, is not specified as being inside a directory, and it is the name used in the command string
		* in general, it is thus safer to prepend the command with "../working" if it is uploaded to the agent, in case the executable is not added to the "executables" dir on the agent
		
* About the stdin and inputFiles and inputFileMap:
	* If inputStream is specified in the task, as defined in inputFiles, and no inputFileMap is used in the task, the file corresponding to the inputStream will be uploaded to the working directory; the inputStream will also be correctly piped to the executable
	* If inputStream is specified in the task, as defined in inputFiles, and an inputFileMap is used in the task, the file corresponding to the inputStream has to be explicitely included in the inputFileMap using the same path as defined in inputFiles; the name can be modified by inputFileMap, but then this same name has to be used as the name in inputStream; this redefined name can include directories
	* Conclusions:
		* the name for inputStream must match the name in inputFiles if no inputFileMap is defined (and can be in a directory)
		* the name for inputStream has to be explicitely added in the inputFileMap is one is defined
		* the name used for inputStream has to match the name defined by inputFileMap (which can be different from inputFiles and can be in a directory)
