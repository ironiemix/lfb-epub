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

* Konfiguration am Skriptbeginn
* Als Option muss das UVV angegeben werden, für welches ein ePub erzeugt werden soll

Das Skript erzeugt ein ePub für eine Aktion des LFB, dabei bezieht es die Unterseiten aus der Datei 
hmenu.txt. Das kann relativ einfach geändert werden, so dass der Redakteur eine analoge Datei epub.txt 
anlegt.

 
