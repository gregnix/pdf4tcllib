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
# The limit is kept here, in Tcl, not by timeout(1): that one comes from
# coreutils, and on Windows "timeout" finds C:\Windows\System32\timeout.exe,
# a pause command that rejects "timeout 120 tclsh ..." ("Die Standardoption
# darf nicht mehr als 1 Mal verwendet werden") -- every example failed.
namespace eval runner {
    variable timeout 120
}

# Run CMD (a list) with the time limit. STREAM 1 passes the output through
# as it arrives (a hanging run must not look like silence), 0 collects it.
# Returns {rc output timedout}; rc is the exit code, -1 when it was killed.
proc runner::execLimited {cmd stream} {
    variable timeout
    variable st
    if {[catch {open [list | {*}$cmd 2>@1] r} ch]} {
        return [list 1 $ch 0]
    }
    set pid [pid $ch]
    chan configure $ch -blocking 0 -translation auto
    # Tcl 9 reads strictly; an example writing in another code page must
    # not stop the run (replace invalid bytes; 8.6 has no -profile)
    catch {chan configure $ch -profile replace}
    set st($ch,out) ""
    unset -nocomplain st($ch,done)
    chan event $ch readable [list apply {{ch stream} {
        if {[catch {read $ch} chunk]} { set chunk "" ; set ::runner::st($ch,done) eof }
        if {$stream} { puts -nonewline $chunk ; flush stdout } \
        else { append ::runner::st($ch,out) $chunk }
        if {[chan eof $ch]} { set ::runner::st($ch,done) eof }
    }} $ch $stream]
    set timer [after [expr {$timeout * 1000}] [list set ::runner::st($ch,done) limit]]
    vwait ::runner::st($ch,done)
    after cancel $timer
    chan event $ch readable {}
    set out $st($ch,out)
    set how $st($ch,done)
    unset -nocomplain st($ch,out) st($ch,done)
    if {$how eq "limit"} {
        if {$::tcl_platform(platform) eq "windows"} {
            catch {exec taskkill /PID $pid /T /F}
        } else {
            catch {exec kill -TERM $pid}
            after 300
            catch {exec kill -KILL $pid}
        }
        catch {close $ch}
        return [list -1 $out 1]
    }
    chan configure $ch -blocking 1
    set rc 0
    if {[catch {close $ch} err opt]} {
        set ec [dict get $opt -errorcode]
        if {[lindex $ec 0] eq "CHILDSTATUS"} {
            set rc [lindex $ec 2]
        } else {
            set rc 1
            append out \n $err
        }
    }
    return [list $rc $out 0]
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
    variable timeout
    set cmd [list [interpFor $f $wishNeeded] $f]
    if {$outdir ne ""} { lappend cmd $outdir }
    lappend cmd {*}$extra
    set t0 [clock milliseconds]
    lassign [execLimited $cmd 0] rc msg timedout
    set ms [expr {[clock milliseconds] - $t0}]
    set msg [string trim $msg]
    if {$timedout} {
        append msg "\nTIME LIMIT ($timeout s) -- does this script run into\
                the event loop? An example that loads Tk and has no exit\
                waits here forever."
    }
    return [list [expr {$rc != 0}] $msg $ms]
}

# Run a sub-runner, with the time limit, its output passed through as it
# comes: a hanging run otherwise looks like silence. That cost time while
# searching for one.
proc runner::runRunner {script args} {
    lassign [execLimited [list [info nameofexecutable] $script {*}$args] 1] \
        rc msg timedout
    if {$timedout} { puts "TIME LIMIT in [file tail $script]" }
    return [expr {$rc != 0}]
}
