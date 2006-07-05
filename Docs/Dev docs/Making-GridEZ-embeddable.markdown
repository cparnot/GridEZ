Instructions for Xcode 2.2

* In the Groups & Files pane, select the target for the GridEZ target
* Open the inspector window by double-clicking or choosing menu File ... Get Info
* Make sure you choose 'All Configurations' in the Configuration pop up menu
* Choose the 'Deployment settings' in the Collection pop-up menu
* Enable the 'Skip install' build setting.
* Set the value of the 'Installation Directory' setting to the following string: @executable_path/../Frameworks

Relevant links:
* http://developer.apple.com/documentation/MacOSX/Conceptual/BPFrameworks/Tasks/CreatingFrameworks.html#//apple_ref/doc/uid/20002258-106880-BAJJBIEF
* http://www.cocoadevcentral.com/articles/000042.php (!!OLD)
