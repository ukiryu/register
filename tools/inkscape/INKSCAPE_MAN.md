# INKSCAPE MAN PAGE

Source: https://inkscape.org/doc/inkscape-man.html

---

## NAME

Inkscape - an SVG (Scalable Vector Graphics) editing program.

## SYNOPSIS

`inkscape [options] [filename_1 filename_2 ...]`

### options:

```
    -?, --help
        --help-all
        --help-gapplication
        --help-gtk

    -V, --version
        --debug-info
        --system-data-directory
        --user-data-directory

    -p, --pipe
    -n, --pages=PAGE[,PAGE]
        --pdf-poppler
        --convert-dpi-method=METHOD
        --no-convert-text-baseline-spacing

    -o, --export-filename=FILENAME
        --export-overwrite
        --export-type=TYPE[,TYPE]*
        --export-extension=EXTENSION-ID

    -C, --export-area-page
    -D, --export-area-drawing
    -a, --export-area=x0:y0:x1:y1
        --export-area-snap
    -d, --export-dpi=DPI
    -w, --export-width=WIDTH
    -h, --export-height=HEIGHT
        --export-margin=MARGIN

        --export-page=all|n[,a-b]
    -i, --export-id=OBJECT-ID[;OBJECT-ID]*
    -j, --export-id-only
    -l, --export-plain-svg
        --export-png-color-mode=COLORMODE
        --export-png-compression=LEVEL
        --export-png-antialias=LEVEL
        --export-png-use-dithering=BOOLEAN
        --export-ps-level=LEVEL
        --export-pdf-version=VERSION
    -T, --export-text-to-path
        --export-latex
        --export-ignore-filters
    -t, --export-use-hints
    -b, --export-background=COLOR
    -y, --export-background-opacity=VALUE

    -I, --query-id=OBJECT-ID[,OBJECT-ID]*
    -S, --query-all
    -X, --query-x
    -Y, --query-y
    -W, --query-width
    -H, --query-height

        --vacuum-defs
        --select=OBJECT-ID[,OBJECT-ID]*
        --actions=ACTION(:ARG)[;ACTION(:ARG)]*
        --action-list
        --actions-file=FILENAME

    -g, --with-gui
    -q, --active-window
        --display=DISPLAY
        --app-id-tag=TAG
        --batch-process
        --shell
```

## DESCRIPTION

**Inkscape** is a Free and open source vector graphics editor. It offers a rich set of features and is widely used for both artistic and technical illustrations such as cartoons, clip art, logos, typography, diagramming and flowcharting. It uses vector graphics to allow for sharp printouts and renderings at unlimited resolution and is not bound to a fixed number of pixels like raster graphics. Inkscape uses the standardized **SVG** file format as its main format, which is supported by many other applications including web browsers.

The interface is designed to be comfortable and efficient for skilled users, while remaining conformant to **GNOME** standards so that users familiar with other GNOME applications can learn its interface rapidly.

**SVG** is a W3C standard XML format for 2D vector drawing. It allows defining objects in the drawing using points, paths, and primitive shapes. Colors, fonts, stroke width, and so forth are specified as `style' attributes to these objects. The intent is that since SVG is a standard, and since its files are text/xml, it will be possible to use SVG files in a sizeable number of programs and for a wide range of uses.

**Inkscape** uses SVG as its native document format, and has the goal of becoming the most fully compliant drawing program for SVG files available in the Open Source community.

## OPTIONS

**-?**, **--help**
:   Shows a help message.

**--help-all**
:   Shows all help options.

**--help-gapplication**
:   Shows the GApplication options.

**--help-gtk**
:   Shows the GTK+ options.

**-V**, **--version**
:   Shows the Inkscape version and build date.

**--debug-info**
:   Prints technical information including Inkscape version, dependency versions and operating system. This Information is useful when debugging issues with Inkscape and should be included whenever filing a bug report.

**--system-data-directory**
:   Prints the system data directory where data files that ship with Inkscape are stored. This includes files which Inkscape requires to run (like unit definitions, built-in key maps, files describing UI layout, icon themes, etc.), core extensions, stock resources (filters, fonts, markers, color palettes, symbols, templates) and documentation (SVG example files, tutorials).

    The location in which Inkscape expects the system data directory can be overridden with the INKSCAPE_DATADIR environment variable.

**--user-data-directory**
:   Prints the user profile directory where user-specific data files and preferences are stored. Custom extensions and resources (filters, fonts, markers, color palettes, symbols, templates) should be installed into their respective subdirectories in this directory. In addition placing a file with a name identical to one in the system data directory here allows to override most presets from the system data directory (e.g. default templates, UI files, etc.).

    The default location of the profile directory can be overridden with the INKSCAPE_PROFILE_DIR environment variable.

**-p**, **--pipe**
:   Reads input file from standard input (stdin).

**--pages**=_PAGE_
:   Imports the given comma separated list of pages from a PDF, or multi page SVG file.

    This replaces the _--pdf-page_ from previous Inkscape versions.

**--pdf-poppler**
:   By default Inkscape imports PDF files via an internal (poppler-derived) library. Text is stored as text. Meshes are converted to tiles. Use --pdf-poppler to import via an external (poppler with cairo backend) library instead. Text consists of groups containing cloned glyphs where each glyph is a path. Images are stored internally. Meshes cause entire document to be rendered as a raster image.

**--convert-dpi-method**=_METHOD_
:   Choose method used to rescale legacy (pre-0.92) files which render slightly smaller due to the switch from 90 DPI to 96 DPI when interpreting lengths expressed in units of pixels. Possible values are \"none\" (no change, document will render at 94% of its original size), \"scale-viewbox\" (document will be rescaled globally, individual lengths will stay untouched) and \"scale-document\" (each length will be re-scaled individually).

**--no-convert-text-baseline-spacing**
:   Do not automatically fix text baselines in legacy (pre-0.92) files on opening. Inkscape 0.92 adopts the CSS standard definition for the 'line-height' property, which differs from past versions. By default, the line height values in files created prior to Inkscape 0.92 will be adjusted on loading to preserve the intended text layout. This command line option will skip that adjustment.

**-o**, **--export-filename**=_FILENAME_
:   Sets the name of the output file. The default is to re-use the name of the input file. If --export-type is also used, the file extension will be adjusted (or added) as appropriate. Otherwise the file type to export will be inferred from the extension of the specified filename.

    Usage of the special filename \"-\" makes Inkscape write the image data to standard output (stdout).

**--export-overwrite**
:   Overwrites input file.

**--export-type**=_TYPE[,TYPE]*_
:   Specify the file type to export. Possible values: svg, png, ps, eps, pdf, emf, wmf and every file type for which an export extension exists. It is possible to export more than one file type at a time.

    Note that PostScript does not support transparency, so any transparent objects in the original SVG will be automatically rasterized. Used fonts are subset and embedded. The default export area is page; you can set it to drawing by --export-area-drawing.

    Note that PDF format preserves the transparency in the original SVG.

**--export-extension**=_EXTENSION-ID_
:   Allows to specify an output extension that will be used for exporting, which is especially relevant if there is more than one export option for a given file type. If set, the file extension in --export-filename and --export-type may be omitted. Additionally, if set, only one file type may be given in --export-type.

**-C**, **--export-area-page**
:   In SVG, PNG, PDF, PS exported area is the page. This is the default for SVG, PNG, PDF, and PS, so you don't need to specify this unless you are using --export-id to export a specific object. For EPS this option is currently not supported.

**-D**, **--export-area-drawing**
:   In SVG, PNG, PDF, PS, and EPS export, exported area is the drawing (not page), i.e. the bounding box of all objects of the document (or of the exported object if --export-id is used). With this option, the exported image will display all the visible objects of the document without margins or cropping. This is the default export area for EPS. For PNG, it can be used in combination with --export-use-hints.

**-a** _x0:y0:x1:y1_, **--export-area**=_x0:y0:x1:y1_
:   In PNG export, set the exported area of the document, specified in px (1/96 in). The default is to export the entire document page. The point (0,0) is the lower-left corner.

**--export-area-snap**
:   For PNG export, snap the export area outwards to the nearest integer px values. If you are using the default export resolution of 96 dpi and your graphics are pixel-snapped to minimize antialiasing, this switch allows you to preserve this alignment even if you are exporting some object's bounding box (with --export-id or --export-area-drawing) which is itself not pixel-aligned.

**-d** _DPI_, **--export-dpi**=_DPI_
:   The resolution used for PNG export. It is also used for fallback rasterization of filtered objects when exporting to PS, EPS, or PDF (unless you specify --export-ignore-filters to suppress rasterization). The default is 96 dpi, which corresponds to 1 SVG user unit (px, also called \"user unit\") exporting to 1 bitmap pixel. This value overrides the DPI hint if used with --export-use-hints.

**-w** _WIDTH_, **--export-width**=_WIDTH_
:   The width of generated bitmap in pixels. This value overrides the --export-dpi setting (or the DPI hint if used with --export-use-hints).

**-h** _HEIGHT_, **--export-height**=_HEIGHT_
:   The height of generated bitmap in pixels. This value overrides the --export-dpi setting (or the DPI hint if used with --export-use-hints).

**--export-margin**=_MARGIN_
:   Adds a margin around the exported area. The size of the margin is specified in units of page size (for SVG) or millimeters (for PS/PDF). The option currently has no effect for other export formats.

**-i** _ID_, **--export-page**=_all|n[,a-b]*
:   Exports the selected pages only. If more than one page is specified then the resulting document may contain multiple pages if the format supports it.

    Value can be a comma separated list of page numbers, or page ranges of two numbers separated by a dash. The keyword 'all' can be used to indicate all pages would be exported.

**-i** _ID_, **--export-id**=_OBJECT-ID[;OBJECT-ID]*_
:   For PNG, PS, EPS, PDF and plain SVG export, the id attribute value of the object(s) that you want to export from the document; all other objects are not exported. By default the exported area is the bounding box of the object; you can override this using --export-area (PNG only) or --export-area-page.

    If you specify many values with a semicolon separated list of objects, each one will be exported separately. In this case the exported files will be named this way: [input_filename]_[ID].[export_type]

**-j**, **--export-id-only**
:   For PNG, PS, EPS, PDF and plain SVG export, only export the object whose id is given in --export-id. All other objects are hidden and won't show in export even if they overlay the exported object. Without --export-id, this option is ignored.

**-l**, **--export-plain-svg**
:   Export document(s) to plain SVG format, without sodipodi: or inkscape: namespaces and without RDF metadata. Use the --export-filename option to specify the filename.

**--export-png-color-mode**=_COLORMODE_
:   Set the color mode (bit depth and color type) for exported bitmaps (Gray_1/Gray_2/Gray_4/Gray_8/Gray_16/RGB_8/RGB_16/GrayAlpha_8/GrayAlpha_16/RGBA_8/RGBA_16)

**--export-png-compression**=_LEVEL_
:   Set the compression level for PNG export (0 to 9); default is 6.

**--export-png-antialias**=_LEVEL_
:   Set the antialiasing level for PNG export (0 to 3); default is 2.

**--export-png-use-dithering**=_false|true_
:   Forces dithering or disables it (the Inkscape build must support dithering for this).

**--export-ps-level**=_LEVEL_
:   Set language version for PS and EPS export. PostScript level 2 or 3 is supported. Default is 3.

**--export-pdf-version**=_VERSION_
:   Select the PDF version of the exported PDF file. This option basically exposes the PDF version selector found in the PDF-export dialog of the GUI. You must provide one of the versions from that combo-box, e.g. \"1.4\". The default pdf export version is \"1.4\".

**-T**, **--export-text-to-path**
:   Convert text objects to paths on export, where applicable (for PS, EPS, PDF and SVG export).

**--export-latex**
:   (for PS, EPS, and PDF export) Used for creating images for LaTeX documents, where the image's text is typeset by LaTeX. When exporting to PDF/PS/EPS format, this option splits the output into a PDF/PS/EPS file (e.g. as specified by --export-type) and a LaTeX file. Text will not be output in the PDF/PS/EPS file, but instead will appear in the LaTeX file. This LaTeX file includes the PDF/PS/EPS. Inputting (\\input{image.tex}) the LaTeX file in your LaTeX document will show the image and all text will be typeset by LaTeX. See the resulting LaTeX file for more information. Also see GNUPlot's `epslatex' output terminal.

**--export-ignore-filters**
:   Export filtered objects (e.g. those with blur) as vectors, ignoring the filters (for PS, EPS, and PDF export). By default, all filtered objects are rasterized at --export-dpi (default 96 dpi), preserving the appearance.

**-t**, **--export-use-hints**
:   While exporting to PNG, use export filename and DPI hints stored in the exported object (only with --export-id). These hints are set automatically when you export selection from within Inkscape. So, for example, if you export a shape with id=\"path231\" as /home/me/shape.png at 300 dpi from document.svg using Inkscape GUI, and save the document, then later you will be able to reexport that shape to the same file with the same resolution simply with

    ```
        inkscape -i path231 -t document.svg
    ```

    If you use --export-dpi, --export-width, or --export-height with this option, then the DPI hint will be ignored and the value from the command line will be used. If you use --export-filename with this option, then the filename hint will be ignored and the filename from the command line will be used.

**-b** _COLOR_, **--export-background**=_COLOR_
:   Background color of exported PNG. This may be any SVG supported color string, for example \"#ff007f\" or \"rgb(255, 0, 128)\". If not set, then the page color set in Inkscape in the Document Properties dialog will be used (stored in the pagecolor= attribute of sodipodi:namedview).

**-y** _VALUE_, **--export-background-opacity**=_VALUE_
:   Opacity of the background of exported PNG. This may be a value either between 0.0 and 1.0 (0.0 meaning full transparency, 1.0 full opacity) or greater than 1 up to 255 (255 meaning full opacity). If not set and the -b option is not used, then the page opacity set in Inkscape in the Document Properties dialog will be used (stored in the inkscape:pageopacity= attribute of sodipodi:namedview). If not set but the -b option is used, then the value of 255 (full opacity) will be used.

**-I**, **--query-id**=_OBJECT-ID[,OBJECT-ID]*_
:   Set the ID(s) of the object(s) whose dimensions are queried in a comma-separated list. If not set, query options will return the dimensions of the drawing (i.e. all document objects), not the page or viewbox.

    If you specify many values with a comma separated list of objects, any geometry query (e.g. --query-x) will return a comma separated list of values corresponding to the list of objects in _--query-id_.

**-S**, **--query-all**
:   Prints a comma delimited listing of all objects in the SVG document with IDs defined, along with their x, y, width, and height values.

**-X**, **--query-x**
:   Query the X coordinate of the drawing or, if specified, of the object with --query-id. The returned value is in px (SVG user units).

**-Y**, **--query-y**
:   Query the Y coordinate of the drawing or, if specified, of the object with --query-id. The returned value is in px (SVG user units).

**-W**, **--query-width**
:   Query the width of the drawing or, if specified, of the object with --query-id. The returned value is in px (SVG user units).

**-H**, **--query-height**
:   Query the height of the drawing or, if specified, of the object with --query-id. The returned value is in px (SVG user units).

**--vacuum-defs**
:   Remove all unused items from the `<defs>` section of the SVG file. If this option is invoked in conjunction with --export-plain-svg, only the exported file will be affected. If it is used alone, the specified file will be modified in place.

**--select**=_OBJECT-ID[,OBJECT-ID]*_
:   The --select command will cause objects that have the ID specified to be selected. You can select many objects width a comma separated list. This allows various verbs to act upon them. To remove all the selections use `--verb=EditDeselect`. The object IDs available are dependent on the document specified to load.

**--actions**=_ACTION(:ARG)[;ACTION(:ARG)]*_
:   Actions are a new method to call functions with an optional single parameter. To get a list of the action IDs available, use the --action-list command line option. Eventually all verbs will be replaced by actions. Temporarily, any verb can be used as an action (without a parameter). Note, most verbs require a GUI (even if they don't use it). To close the GUI automatically at the end of processing, use --batch-process. In addition all export options have matching actions (remove the '--' in front of the option and replace '=' with ':').

    If only actions are used --batch-process must be used.

    Export can be forced at any point with the export-do action. This allows one to do multiple exports on a single file.

**--action-list**
:   Prints a list of all available actions.

**--actions-file**=_FILENAME_
:   Execute all actions listed in the file. The file contents must be formatted using the syntax of --actions. This option overrides the --actions argument when both are given.

**-g**, **--with-gui**
:   Try to use the GUI (on Unix, use the X server even if $DISPLAY is not set).

**-q**, **--active-window**
:   Instead of launching a new Inkscape process, this will run the command in the most recently focused Inkscape document.

**--display**=_DISPLAY_
:   Sets the X display to use for the Inkscape window.

**--app-id-tag**=_TAG_
:   Creates a unique instance of Inkscape with the application ID 'org.inkscape.Inkscape.TAG'. This is useful to separate the Inkscape instances when running different Inkscape versions or using different preferences files concurrently.

**--batch-process**
:   Close GUI after executing all actions or verbs.

**--shell**
:   With this parameter, Inkscape will enter an interactive command line shell mode. In this mode, you type in commands at the prompt and Inkscape executes them, without you having to run a new copy of Inkscape for each command. This feature is mostly useful for scripting and server uses: it adds no new capabilities but allows you to improve the speed and memory requirements of any script that repeatedly calls Inkscape to perform command line tasks (such as export or conversions).

    In shell mode Inkscape expects a sequence of actions (or verbs) as input. They will be processed line by line, that means typically when pressing enter. It is possible (but not necessary) to put all actions on a single line.

    This option can be combined with the --active-window parameter, to execute the shell commands in an already opened Inkscape document.

    The following example opens a file and exports it into two different formats, then opens another file and exports a single object:

    ```
        file-open:file1.svg; export-type:pdf; export-do; export-type:png; export-do
        file-open:file2.svg; export-id:rect2; export-id-only; export-filename:rect_only.svg; export-do
    ```

## EXAMPLES

While obviously **Inkscape** is primarily intended as a GUI application, it can be used for doing SVG processing on the command line as well.

Open an SVG file in the GUI:

```
    inkscape filename.svg
```

Export an SVG file into PNG with the default resolution of 96 dpi (one SVG user unit translates to one bitmap pixel):

```
    inkscape --export-filename=filename.png filename.svg
```

Same, but force the PNG file to be 600x400 pixels:

```
    inkscape --export-filename=filename.png -w 600 -h 400 filename.svg
```

Same, but export the drawing (bounding box of all objects), not the page:

```
    inkscape --export-filename=filename.png --export-area-drawing filename.svg
```

Export two different files into four distinct file formats each:

```
    inkscape --export-type=png,ps,eps,pdf filename1.svg filename2.svg
```

Export to PNG the object with id=\"text1555\", using the output filename and the resolution that were used for that object last time when it was exported from the GUI:

```
    inkscape --export-id=text1555 --export-use-hints filename.svg
```

Same, but use the default 96 dpi resolution, specify the filename, and snap the exported area outwards to the nearest whole SVG user unit values (to preserve pixel-alignment of objects and thus minimize aliasing):

```
    inkscape --export-id=text1555 --export-filename=text.png --export-area-snap filename.svg
```

Convert an Inkscape SVG document to plain SVG:

```
    inkscape --export-plain-svg --export-filename=filename2.svg filename1.svg
```

Convert an SVG document to EPS, converting all texts to paths:

```
    inkscape --export-filename=filename.eps --export-text-to-path filename.svg
```

Query the width of the object with id=\"text1555\"):

```
    inkscape --query-width --query-id=text1555 filename.svg
```

Duplicate the objects with id=\"path1555\" and id=\"rect835\", rotate the duplicates 90 degrees, save SVG, and quit:

```
    inkscape --select=path1555,rect835 --actions=\"duplicate;object-rotate-90-cw\" --export-overwrite filename.svg
```

Select all objects with ellipse tag, rotate them 30 degrees, save the file, and quit.

```
    inkscape --actions=\"select-by-element:ellipse;transform-rotate:30\" --export-overwrite filename.svg
```

Export the object with the ID MyTriangle with a semi transparent purple background to the file triangle_purple.png and with a red background to the file triangle_red.png.

```
    inkscape --actions=\"export-id:MyTriangle; export-id-only; export-background:purple; export-background-opacity:0.5;export-filename:triangle_purple.png; export-do; export-background:red; export-background-opacity:1; export-filename:triangle_red.png; export-do\" filename.svg
```

Read an SVG from standard input (stdin) and export it to PDF format:

```
    cat filename.svg | inkscape --pipe --export-filename=filename.pdf
```

Export an SVG to PNG format and write it to standard output (stdout), then convert it to JPG format with ImageMagick's convert program:

```
    inkscape --export-type=png --export-filename=- filename.svg | convert - filename.jpg
```

Same as above, but also reading from a pipe (--export-filename can be omitted in this case)

```
    cat filename.svg | inkscape --pipe --export-type=png | convert - filename.jpg
```

## ENVIRONMENT VARIABLES

**INKSCAPE_PROFILE_DIR**
:   Set a custom location for the user profile directory.

**INKSCAPE_DATADIR**
:   Set a custom location for the Inkscape data directory (e.g. **$PREFIX**/share if Inkscape's shared files are in **$PREFIX**/share/inkscape).

**INKSCAPE_LOCALEDIR**
:   Set a custom location for the translation catalog.

For more details see also http://wiki.inkscape.org/wiki/index.php/Environment_variables

## SEE ALSO

potrace, cairo, rsvg, batik, ghostscript, pstoedit.

SVG compliance test suite: https://www.w3.org/Graphics/SVG/WG/wiki/Test_Suite_Overview

SVG validator: https://validator.w3.org/

**Scalable Vector Graphics (SVG) 1.1 Specification** _W3C Recommendation 16 August 2011_ https://www.w3.org/TR/SVG11/

**Scalable Vector Graphics (SVG) 1.2 Specification** _W3C Working Draft 13 April 2005_ https://www.w3.org/TR/SVG12/

**Scalable Vector Graphics (SVG) 2 Specification** _W3C Candidate Recommendation 15 September 2016_ https://www.w3.org/TR/SVG2/

**Document Object Model (DOM): Level 2 Core** _W3C Recommendation 13 November 2000_ https://www.w3.org/TR/DOM-Level-2-Core/

## COPYRIGHT AND LICENSE

**Copyright (C)** 1999-2023 by Authors.

**Inkscape** is free software; you can redistribute it and/or modify it under the terms of the GPL version 2 or later.
