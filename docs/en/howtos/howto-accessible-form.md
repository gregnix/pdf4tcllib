# How-to: a form whose fields have names

```bash
tclsh docs/en/howtos/howto-accessible-form.tcl
```

Companion: [`howto-accessible-form.tcl`](howto-accessible-form.tcl).

## Load the font through pdf4tcllib, not around it

```tcl
::pdf4tcllib::fonts::init -fontdir [file dirname $ttf]
::pdf4tcllib::fonts::setFont $pdf 11 [::pdf4tcllib::fonts::fontSans]
```

The building blocks take their own font from that configuration. Setting a
font with `$pdf setFont` alone is not enough: `form::section` then still
draws its title in `Helvetica-Bold`, which is exactly the font that cannot
be embedded, and the PDF/UA warning names a font the caller never asked
for. That was measured, and it is why the blocks now follow `fonts::init`.

## The form itself

```tcl
$pdf tagged 1 -ua 1 -lang en-GB
::pdf4tcllib::form::section    $pdf $ctx y "Delivery address"
::pdf4tcllib::form::labelField $pdf $ctx y "Name" text -id nm
::pdf4tcllib::form::row        $pdf $ctx y {
    {label "Postcode:" type text width 160 id plz}
    {label "Town:"     type text width 220 id ort}
}
::pdf4tcllib::form::separator  $pdf $ctx y
```

What that produces:

| | |
|---|---|
| section title | `H2` -- it heads the block it opens |
| bar, frame, separator | Layout artifacts |
| each field | a `Form` element holding **both** the label and the field's `/OBJR` |

The label sitting inside the element is the point. A field outside the tree
cannot be reached at all, and a caption outside it names nothing -- before
0.6.1 that was one untagged painting operation per field, which reads as an
input with no visible name.

## Why `-ua 1`

It makes pdf4tcl check what PDF/UA requires and say so when the document
falls short -- the font warning above is one of those. Without it the file
is tagged and nobody claims anything.

## Checking

```bash
verapdf -f ua1 out.pdf
verapdf -f 3a  out.pdf
```

Run both. A PDF/UA conformant document can fail PDF/A outright and the
other way round; the interesting errors sit between the profiles.

`qpdf --check` says nothing about conformance -- it reads the bytes. Worth
running anyway: it has found real defects in this project that no validator
reported.
