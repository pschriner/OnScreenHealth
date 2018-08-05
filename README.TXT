
OnScreenHealth is a World of Warcraft user interface addon to provide
a textual display of vital stats for the player, target, and pet units.

------------------------------------------------------------------------
Download:

- http://www.wowinterface.com/downloads/info7470-OnScreenHealth.html
- http://www.curse.com/downloads/wow-addons/details/onscreenhealth.aspx

------------------------------------------------------------------------
Usage:

Type "/osh" in-game for a list of available commands.

------------------------------------------------------------------------
Notes on text formatting:

The health and power text format options make use of a simple token
system, similar to that used in macros. The token will be replaced with
the appropriate formatted value when displayed. The following tokens are
available in OnScreenHealth:

	$c		current value
	$m		maxmimum value
	$d		deficit value (how much is missing)
	$p		percent value

Adding ":c" to the end of the $c, $m, and $d tokens will shorten the
formatted value. For example, if the unit's current health is 1,406,739
and you have entered the format "$c:s", the value will be displayed as
"1.4m".

Multiple tokens and non-token characters may be used in a format string.
For example, healers may like to see both the current and deficit values:

	$c - $d	->	17401 - 3956

Pure damage-dealing classes may prefer instead to see the current and
percent values:

	$c ($p%)	->	17401 (81%)

------------------------------------------------------------------------
Localization:

Compatible with: all locales.

Translated into: enUS, ruRU, koKR, zhCN.

If you would like to assist with translation for any locale, please
contact me using the contact information listed below.

------------------------------------------------------------------------
Feedback:

Please use the bug report and feature request ticket systems on either
download page to report specific problems and request specific features.

Use the comments section on the download page for general feedback only.

If private communication is necessary, I can be contacted...
- by email: addons@phanx.net
- by in-game mail: Phanx on US Blackrock Horde
- by private message: Phanx on wowinterface.com or wowace.com

------------------------------------------------------------------------
Credits:

- Blink for the concept via his Blink Health Text addon.
- Alumno for requesting a new addon in the same vein.
- Damjau for the original pet code.
- Rdji for the combat indicator idea.
- All of the translators, as named in the translation files.

------------------------------------------------------------------------
License:

Copyright © 2007–2008 Alyssa Kinley, a.k.a. Phanx

The code in this addon is copyrighted to its author, with all rights reserved,
under United States and international copyright law. The author of this addon
hereby grants you the following rights:

You MAY download, install, and run this addon for your own personal use.

You MAY NOT redistribute this addon, modified or unmodified, including as part
of a compilation, without the express prior consent of its author.

You MAY use the code from this addon, in whole or in part, in your own addon,
provided that the name and code of your addon contain no references to the name
of this addon or its author.
