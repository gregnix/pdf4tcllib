# _runner.tcl -- the parts both example runners share.
#
# Read by basic/run_basic.tcl and advanced/run_advanced.tcl. These
# procedures used to sit in both files, nearly but not quite alike -- a
# list that lives in two places is wrong in one of them, and it was:
# advanced knew a time limit, basic did not.

# Derive the interpreter from the running one instead of looking for
# "tclsh"/"wish" in the PATH. Otherwise the run checks whichever generation
# happens to come first there -- started under 9.0, measured under 8.6.
proc runner::interpFor {f wishNeeded} {
    set self [info nameofexecutable]
    if {!$wishNeeded} { return $self }
    set cand [file join [file dirname $self] \
                  [string map {tclsh wish} [file tail $self]]]
    if {[file executable $cand]} { return $cand }
    return $self
}

# Time limit per script. Without one exec waits forever, and an example
# that loads Tk and has no exit holds up the whole run -- on a machine with
# a display, while the same run passes without DISPLAY because Tk fails to
# load there in the first place.
#
# timeout(1) comes from coreutils and is absent on Windows; there this runs
# as before, without a limit.
namespace eval runner {
    variable timeout 120
    variable timeoutCmd {}
    if {[llength [auto_execok timeout]] > 0} {
        set timeoutCmd [list timeout $timeout]
    }
}

# Sammle die Skripte eines Verzeichnisses ein und pruefe, dass es plausibel
# viele sind. Grund: eine fehlabgelegte Kopie von run_advanced.tcl lag mit
# drei Beispielen im Wurzelverzeichnis, ihr glob fand genau diese drei, und
# der Lauf meldete "2 OK / 0 Fehler" -- er sah aus wie ein bestandener
# advanced-Lauf und hatte 3 von 36 Skripten gesehen. Nicht rot, sondern
# unvollstaendig gruen, und das ist schlechter.
#
# $least ist die Zahl, unter der etwas nicht stimmen KANN -- keine
# Sollzahl, sondern eine Untergrenze. Sie wird gemeldet, nicht erzwungen:
# wer ein Verzeichnis absichtlich leert, soll es tun duerfen und es sehen.
proc runner::collect {dir pattern least what} {
    set found [lsort [glob -nocomplain -directory $dir $pattern]]
    if {[llength $found] < $least} {
        puts "WARNUNG: nur [llength $found] $what in [file normalize $dir]"
        puts "         erwartet waeren mindestens $least. Laeuft dieser Runner"
        puts "         im richtigen Verzeichnis? Eine verirrte Kopie findet"
        puts "         ihre eigenen Nachbarn und meldet den Lauf als bestanden."
    }
    return $found
}

# Run one script. Returns {rc output milliseconds}.
#   wishNeeded  1 when the script needs a window
#   extra       further arguments, AFTER the output directory
proc runner::runScript {f outdir {wishNeeded 0} {extra {}}} {
    variable timeoutCmd
    variable timeout
    set cmd [list {*}$timeoutCmd [interpFor $f $wishNeeded] $f]
    if {$outdir ne ""} { lappend cmd $outdir }
    lappend cmd {*}$extra
    set t0 [clock milliseconds]
    set rc [catch { exec {*}$cmd 2>@1 } msg]
    set ms [expr {[clock milliseconds] - $t0}]
    # Tcl haengt bei rc!=0 "child process exited abnormally" an die
    # Ausgabe. In der FAIL-Zeile steht dann hinter der eigentlichen
    # Ursache ("can't find package tkpath") noch ein Satz, der nichts
    # sagt und wie ein zweiter Fehler aussieht.
    set msg [string trim [string map \
            {"child process exited abnormally" ""} $msg]]
    if {$rc && [lindex $::errorCode 0] eq "CHILDSTATUS"
            && [lindex $::errorCode 2] == 124} {
        append msg "\nTIME LIMIT ($timeout s) -- does this script run into\
                the event loop? An example that loads Tk and has no exit\
                waits here forever."
    }
    return [list $rc $msg $ms]
}

# Run a sub-runner, with the time limit and without collecting its output:
# exec otherwise holds everything back until the end, and a hanging run
# then looks like silence. That cost time while searching for one.
proc runner::runRunner {script args} {
    variable timeoutCmd
    set cmd [list {*}$timeoutCmd [info nameofexecutable] $script {*}$args]
    set rc [catch { exec {*}$cmd >@stdout 2>@stderr } msg]
    if {$rc && [lindex $::errorCode 0] eq "CHILDSTATUS"
            && [lindex $::errorCode 2] == 124} {
        puts "TIME LIMIT in [file tail $script]"
    } elseif {$msg ne ""} {
        puts $msg
    }
    return $rc
}
