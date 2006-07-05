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