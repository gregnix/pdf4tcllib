# _utf8.tcl -- die Demo als UTF-8 lesen, egal was die Maschine meint
#
# Tcl 8.6 liest eine Skriptdatei in der SYSTEMKODIERUNG. Auf einem
# deutschen Windows ist das cp1252, die Demos liegen aber in UTF-8 --
# also wird jedes Umlautbyte einzeln uebersetzt:
#
#   aeoeue  ->  A-Tilde-Currency ...   (gemeldet 05.09.2026, Tcl 8.6.17)
#
# Tcl 9 liest Skripte immer als UTF-8; dort passiert nichts von alledem,
# und dieser Vorspann ist ein Leerlauf.
#
# WIE ES REPARIERT WIRD: die Datei liest sich selbst noch einmal, diesmal
# mit angegebener Kodierung. "source -encoding" gibt es seit Tcl 8.5.
# Das Rekursionsende ist die Variable unten -- ohne sie laedt sich die
# Datei endlos selbst.
#
# WORAN ES ERKANNT WIRD: an einem Zeichen, nicht an einer Vermutung ueber
# die Plattform. Ein "a-Umlaut" ist EIN Zeichen; kommt er als zwei an,
# wurde die Datei falsch gelesen. Das ist unabhaengig von Betriebssystem,
# Locale und Tcl-Fassung -- und es misst genau das, was schiefgeht.
#
# EINBAU in eine Demo, als erste Zeile nach dem Kopf:
#
#   source [file join [file dirname [info script]] .. _utf8.tcl]
#
# Danach steht der Rest der Datei richtig da.

if {![info exists ::pdf4tcllibUtf8Neuladen]} {
    # "\u00e4" ist hier bewusst als Escape geschrieben: dieser Vorspann
    # muss in JEDER Kodierung gleich gelesen werden, sonst prueft er sich
    # selbst kaputt.
    if {[string length "\u00e4"] != 1} {
        # Kann eigentlich nicht sein -- ein Escape ist immer ein Zeichen.
        # Wenn doch, ist etwas so grundlegend anders, dass Schweigen
        # falsch waere.
        puts stderr "_utf8.tcl: die Escape-Pruefung selbst schlaegt fehl"
    }
    set ::pdf4tcllibUtf8Aufrufer [info script]
}

# Der eigentliche Test laeuft in der AUFRUFENDEN Datei, nicht hier: nur
# dort stehen die Literale, um die es geht. Diese Prozedur bekommt eines
# davon zu sehen.
proc utf8Pruefen {probe} {
    # Die Probe ist ein Literal aus der Aufruferdatei, das genau ein
    # Zeichen enthalten soll. Kommt mehr an, wurde die Datei byteweise
    # falsch uebersetzt.
    if {[string length $probe] == 1} { return 1 }
    return 0
}

# Die Aufruferdatei noch einmal lesen, diesmal als UTF-8. Gibt 1 zurueck,
# wenn neu geladen wurde -- der Aufrufer beendet sich dann selbst mit
# "return", damit sein Rest nicht zweimal laeuft.
proc utf8Neuladen {datei} {
    if {[info exists ::pdf4tcllibUtf8Neuladen]} { return 0 }
    set ::pdf4tcllibUtf8Neuladen 1
    # "uplevel #0": source wertet das Skript im Rahmen des AUFRUFERS
    # aus. Von hier -- aus einer Prozedur -- wuerde jedes "set" der
    # Demo eine LOKALE Variable dieser Prozedur, und die Demo bricht
    # spaeter mit
    #   can't read "demo_num": no such variable
    # ab. Gemessen am 05.09.2026; die Umlaute waren da schon richtig,
    # die Demo lief trotzdem nicht.
    if {[catch {uplevel #0 [list source -encoding utf-8 $datei]} fehler]} {
        unset -nocomplain ::pdf4tcllibUtf8Neuladen
        return -code error "_utf8.tcl: erneutes Laden von\
                [file tail $datei] scheiterte: $fehler"
    }
    return 1
}
