XMMS App Wrapper for GWorkspace
===============================


How to set the action for xmms?
-------------------------------

Normally, the sript will start xmms just with the filename as parameter 
so xmms will replace the currently active playlist with that file. If 
you want to change that behavior, change the value of FileOpenAction in
the XMMS domain of your user default by "Enqueue" or "EnqueueAndPlay":
defaults write XMMS FileOpenAction Enqueue
defaults write XMMS FileOpenAction EnqueueAndPlay

To use the EnqueueAndPlay options the xmms-add-play tool must be installed (included with the xmms-ctrl pakage, see www.xmms.org for more information). Also EnqueueAndPlay does not work for playlists and if xmms is currently paused.

To restore the default behavior, just the set another value, or erase 
the key:
defaults delete XMMS FileOpenAction



Credits
-------

The Icons were created by Marco <fatal@global.uibk.ac.at>

