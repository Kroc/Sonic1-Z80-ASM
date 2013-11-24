===============================================================================
ReadMe.txt               Visual Binary Diff 3.0_beta4               26-Jul-2008
===============================================================================
                                      Copyright 2000-2008 Christopher J. Madsen
CONTENTS
========
  [1] About Visual Binary Diff
  [2] System Requirements
  [3] Installation
  [4] Removal
  [5] License
  [6] History
  [7] Author

[1] About Visual Binary Diff
----------------------------
Visual Binary Diff (VBinDiff) displays files in hexadecimal and ASCII
(or EBCDIC).  It can also display two files at once, and highlight the
differences between them.  Unlike diff, it works well with large files
(up to 4 GB).

VBinDiff was inspired by the Compare Files function of the ProSel
utilities by Glen Bredon, for the Apple II.  When I couldn't find a
similar utility for the PC, I wrote it myself.

The single-file mode was inspired by the LIST utility of 4DOS and
friends (http://www.jpsoft.com/4ntdes.htm).  While less
(http://www.greenwoodsoftware.com/less/) provides a good line-oriented
display, it has no equivalent to LIST's hex display.  (True, you can
pipe the file through hexdump, but that's incredibly inefficient on
multi-gigabyte files.)


[2] System Requirements
-----------------------
Windows 95, Windows NT 4.0, or later
  or
A POSIX-compatible system with ncurses (eg, Linux)

It should be possible to port the ncurses version to work with other
curses libraries (as long as they provide the panel library), but I
don't have access to such a system.  Patches are welcome.


[3] Installation
----------------
Copy VBinDiff.exe to a folder on your path.  If you don't know what a path
is, you can put it in your C:\Windows directory.  Then read VBinDiff.txt to
find out how to use it.


[4] Removal
-----------
To remove VBinDiff, just delete it.  It makes no registry changes or INI
files.

The following files are included with VBinDiff (and should be deleted):
  ReadMe.txt	This file
  AUTHORS.txt   Credits
  COPYING.txt   The GNU General Public License
  VBinDiff.exe	The main program
  VBinDiff.txt	The documentation
  Source.zip    The source code for VBinDiff


[5] License
-----------
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, see <http://www.gnu.org/licenses/>.

The GNU General Public License can be found in the file COPYING.txt.

The file putty.src is not part of VBinDiff and can be distributed
under the same terms as ncurses.


[6] History
-----------
* 26 Jul 2008     VBinDiff 3.0 beta 4

  Fixed a major bug in the Win32 hex editor
   (which caused it to crash after saving changes)
  Added --enable-debug configure option
  Clarified licensing

* 25 Jun 2008     VBinDiff 3.0 beta 3

  The line editor now has an input history
  Space now moves to the next difference (same as Enter)
  win32/vbindiff.rc had been left out of the source archive

*  7 Jun 2008     VBinDiff 3.0 beta 2

  Improved the line editor (used for entering search strings, etc.)
  Updated my email address

* 11 Nov 2005     VBinDiff 3.0 beta 1

  Added a POSIX (eg, Linux) version alongside the Win32 version
  Added single-file mode
  Added EBCDIC support
  Added support for resized consoles (no longer assumes 80x25)

* October 2004    VBinDiff 2.x

  Added support for editing files
  Never publicly released

* October 1997    VBinDiff 2.x

  Ported from OS/2 to Win32 (OS/2 support dropped)
  Never publicly released

* January 1996    VBinDiff 1.x

  First public release of VBinDiff (OS/2 version)


[7] Author
----------
Christopher J. Madsen           vbindiff AT cjmweb.net
1113 Abrams Rd. Apt. 296
Richardson, TX  75081-5573

VBinDiff Home Page:
http://www.cjmweb.net/vbindiff/
