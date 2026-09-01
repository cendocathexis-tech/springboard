Fonts for SpringBoard Widget Designer
====================================

Drop .ttf or .otf files into:

  /var/mobile/Library/Preferences/com.yourname.designer/Fonts

Use Filza, or Files if you have a jailbreak file provider.

The editor scans this folder and injects @font-face (base64) into WKWebView.
You do not need to install the font into iOS.

This package folder is only a fallback location:

  /var/jb/Library/Application Support/SBWidgetDesigner/Fonts
