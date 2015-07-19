Skript, um auf dem LFB epubs zu erzeugen
=========================================

Zusätzliche Software für den LFB-Server
----------------------------------------

* perl-File-Copy-Recursive
* perl-Filforeach (@images) 
* perl-HTML-TokeParser-Simple
* pandoc

Sollte es alles in den CentOS Paketquellen geben.

Funktionsweise
----------------

* Konfiguration am Skriptbeginn, Erläuterungen in den Kommentaren.
* Als Option muss das UVZ angegeben werden, für welches ein ePub erzeugt werden soll, relativ zur LFB Document-Root, also z.B. `./lfbepubcreator.pl -s netz/muster/linux/material/unterricht/`
* Das Skript erzeugt ein ePub mit dem Namen `ebook.epub` für einen Teilbereich des LFB, dabei bezieht es die Unterseiten aus der Datei hmenu.txt. Das kann relativ einfach geändert werden, so dass der Redakteur beispielsweise eine analoge Datei epub.txt anlegt. Rekursion geht derzeit nicht, kann aber implementiert werden wenn nötig/gewünscht.

Möglicher Workflow
-------------------

* Der Redakteur legt nach einer Änderung eine Datei create_epub im Seitenbereich an
* Ein Cronjob erzeugt für die so festgelegten Bereiche die epub-Version
* mason muss so angepasst werden, dass es einen Link auf das ePub anzeigt, sobald die epub-Datei vorhanden ist


ToDo
----

* Links auf Unterseiten zeigen derzeit noch ins Netz
* CSS für ePub anpassen
* Rekursion für größere Seitenbereiche?

 
