# How-to: images, and the text that makes them mean something

```bash
tclsh docs/en/howtos/howto-images.tcl
```

Companion: [`howto-images.tcl`](howto-images.tcl). Needs Tk and a display;
without one the script says so and exits 0.

## Ask for Tk yourself

```tcl
if {[catch {package require Tk} e]} {
    puts "skipped -- this how-to needs Tk and a display"
    exit 0
}
```

pdf4tcllib stopped loading Tk when the module is read: only the image
helpers need it, and pulling it into every batch script meant every script
without an exit hung on a machine with a display -- while the same run
passed without one, because loading Tk failed there. So the helpers ask for
Tk at call time, and a script that wants an image asks for it too.

## The image

```tcl
::pdf4tcllib::tag::begin $pdf Figure -alt "Colour gradient, blue to orange"
::pdf4tcllib::image::insert $pdf demoImg 50 y 300 40 780 pageNo 595 842 25 10
::pdf4tcllib::tag::end $pdf
```

`insert` scales the image to the given width and starts a new page when it
no longer fits, updating `y` and `pageNo` as it goes.

The `Figure` and its alternate text are yours to add. **The alt text is the
one thing no tool can supply**: ISO 14289-1 clause 7.3 requires it, and a
`Figure` without it tells a reader that something is there and nothing
about what.

Write what the picture says, not what it is. "Colour gradient, blue to
orange" is useful; "image" and "figure1.png" are not.

## A caption is not part of the figure

```tcl
::pdf4tcllib::tag::begin $pdf Caption
$pdf text "Figure 1: a gradient" -x 50 -y $y
::pdf4tcllib::tag::end $pdf
```

## When a picture means nothing

Mark it as an artifact:

```tcl
::pdf4tcllib::tag::artifact $pdf -type Layout
$pdf rectangle 50 $y 300 8 -filled 1
::pdf4tcllib::tag::artifactEnd $pdf
```

A `Figure` with alt text "decorative line" is worse than an artifact: it
makes a reader stop for something that carries no meaning.
