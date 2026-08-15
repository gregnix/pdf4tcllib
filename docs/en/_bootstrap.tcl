# _bootstrap.tcl -- shared helpers for the howto and tutorial scripts.
#
# Source from a script under howtos/ or tutorials/:
#   source [file join [file dirname [info script]] ../_bootstrap.tcl]
#   pdf4tcllib::doc::init [info script]
#   set out [pdf4tcllib::doc::outfile basename.pdf]

namespace eval ::pdf4tcllib::doc {
    variable outdir
    variable ttf
}

# Sets up the module path, loads the packages and settles the output
# directory. Pass [info script] -- the scripts live one level down and the
# path cannot be guessed from here.
proc ::pdf4tcllib::doc::init {scriptfile {extraOut ""}} {
    variable outdir
    if {$scriptfile eq "" || [file tail $scriptfile] eq "_bootstrap.tcl"} {
        return -code error "pdf4tcllib::doc::init needs the script path:\
                pdf4tcllib::doc::init \[info script\]"
    }
    set here [file dirname [file normalize $scriptfile]]
    set root [file normalize [file join $here ../../..]]

    tcl::tm::path add [file join $root lib]
    # pdf4tcl may sit beside the library rather than on auto_path.
    foreach cand [list [file join $root .. pdf4tcl pkg] \
                       [file join $root .. pdf4tcl]] {
        if {[file isdirectory $cand]} {
            set ::auto_path [linsert $::auto_path 0 [file normalize $cand]]
        }
    }
    package require pdf4tcl
    package require pdf4tcllib

    set outdir [file join [file dirname $here] out]
    if {$extraOut ne ""} { set outdir $extraOut }
    # First argument is the output directory, as everywhere else in this
    # repository -- never a file name.
    if {[llength $::argv] > 0} {
        set a [lindex $::argv 0]
        if {$a ne "" && ![string match -* $a]} { set outdir $a }
    }
    file mkdir $outdir
    return $outdir
}

proc ::pdf4tcllib::doc::outfile {name} {
    variable outdir
    return [file join $outdir $name]
}

# A TrueType font, or "" when none is installed. Tagged documents need one:
# the 14 standard fonts have no embeddable font program, so PDF/A and
# PDF/UA rule them out.
proc ::pdf4tcllib::doc::findTTF {} {
    variable ttf
    if {[info exists ttf]} { return $ttf }
    set ttf ""
    foreach cand {
        /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
        /usr/share/fonts/truetype/freefont/FreeSans.ttf
        /usr/share/fonts/TTF/DejaVuSans.ttf
        C:/Windows/Fonts/arial.ttf
    } {
        if {[file readable $cand]} { set ttf $cand; break }
    }
    return $ttf
}

# Report what the document left outside the structure tree, then write it.
# Every script here ends this way -- the number is the point of the
# exercise, not a decoration.
proc ::pdf4tcllib::doc::finish {pdf out} {
    set left [$pdf getUntaggedCount]
    $pdf write -file $out
    $pdf destroy
    puts "wrote $out"
    puts "untagged painting operations: $left"
    if {$left != 0} {
        puts "  -> content belonging to neither an element nor an artifact"
    }
    foreach w $::pdf4tcl::warnings {
        puts "warning: [string range $w 0 100]"
    }
    return $left
}
