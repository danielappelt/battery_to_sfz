battery_to_sfz
==============

battery_to_sfz allows the conversion of [Native Instruments Battery][1] v1 (.kit) files into [sfz format][2].

Requirements
------------

A [XSLT processor][3] like xsltproc (part of [libxslt][4]) is required to run the conversion script.

Usage
-----

Batch conversion using bash script:

    cd src/bash
    ./battery_to_sfz <path to folder containing .kit file(s)>


Individual conversion using xsltproc (stringparams are optional):

    cd src/xsl
    xsltproc --noout -o <output .sfz file> --stringparam uppercaseFileNames <yes|no>
        --stringparam pathPrefix <path to samples relative to the generated sfz file>
        --stringparam maxEGTime <seconds> battery_to_sfz.xsl <battery .kit file>

Features
--------

* Battery settings like volume, pan, mute groups, and velocity layers are faithfully recreated
* volume and pitch envelopes get converted to some extend
* resulting sfz files are quite readable

License
-------

See the [LICENSE](LICENSE) file.

[1]: http://www.native-instruments.com/en/products/producer/battery-3/
[2]: http://www.cakewalk.com/DevXchange/article.aspx?aid=108
[3]: http://en.wikipedia.org/wiki/XSLT#Processor_implementations
[4]: http://xmlsoft.org/XSLT/
