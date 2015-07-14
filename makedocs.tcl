#!/usr/bin/tclsh
package require doctools

set data {
[manpage_begin mustache n 1.1.3]
[moddesc   {mustache.tcl}]
[titledesc {mustache templating engine}]
[copyright "2015 Jan Kandziora <jjj@gmx.de>, BSD-2-Clause license"]
[keywords "template processing" html]
[require Tcl 8.5]
[require lambda]
[require mustache [opt 1.1.3]]

[description]
This package is a pure-Tcl implementation of the mustache templating engine spec
which can be found at[nl]
[uri https://github.com/mustache/spec/tree/master/specs][nl]
v1.1.3 of the spec and the optional lambda part are supported.[nl]
See [uri http://mustache.github.io/] for further information on mustache.


[section PROCEDURES]
The package defines the following public procedure:
[list_begin definitions]

[call [cmd ::mustache::mustache] [arg template] [arg context] [opt "[arg libraryvar] ..."]]
Process the mustache [arg template] with the given [arg context].
Mustache partials are supplied from variables in the scope of the caller;
if such a variable doesn't exist, the [arg libraryvar] variables are consulted, in given order.
Each library variable has to contain a dict of partials, where the key is the name of the partial;
they may be in any scope, default is the scope of the caller.

[list_end]

[subsection "SECURITY CONCERN:"]
[emph Important:] You have to read and understand this whether you plan to use lambdas or not
- the security threat is always there, as it has its origins in user supplied content (which may be a lambda - at a [emph "malicious user's choice"]).
[para]
Because Tcl doesn't support explicit typing, there is no standard way to flag content as "executable"
and neither "non-executable". The latter raises a security threat - Tcl injection, like in SQL injection -
when handling user supplied contexts (read: [emph always]).
To nullify that threat, take [emph "at least one"] of the following measures:
[list_begin bullet]

[bullet] Make use of the [emph "lambda unsafe"] feature, see [sectref "LAMBDA-UNSAFE SECTIONS"] below.

[bullet] Put the whole template->output generator into a [emph "safe interpreter"], e.g. by doing
[example_begin]

set mustacheinterp [lb]::safe::interpCreate[rb]
puts [lb]$mustacheinterp eval {
	package require mustache
	set template {<h1>{{usercontent}},</h1>}
	set context [lb]dict create usercontent {Λtcl {open "evildoing" w+}}[rb]
	::mustache::mustache $template $context
}[rb]

[example_end]

[list_end]

[section VARIABLES]
The following public variables are defined:
[list_begin definitions]
[lst_item "set [var ::mustache::lambdaPrefix] \"Λtcl\""]
Stores the prefix used to detect a lambda in context. Can be changed should this ever be needed.
[lst_item "set [var ::mustache::lambdaUnsafe] \"λtcl\""]
Stores the prefix used to mark a section as lambda-unsafe. Can be changed should this ever be needed.
[list_end]

[section "CONTEXT PROCESSING"]
Context values are processed before they are put into the template to render the output.
[subsection TEXTS]
Context values that are texts are HTML-escaped after processing.
This is required by the mustache spec and can be disabled selectively in some cases.

[subsection NUMBERS]
Context values that are integers are treated as text for value tags.
Context values that are doubles are treated as such for value tags:
leading and trailing zeroes are removed as expected for numbers.
This is required by the mustache spec and cannot be disabled.

[subsection BOOLEANS]
Context values that are Tcl booleans (integers, "false", "true", "no", "yes") are treated as such
for section tags (meaning they turn on/off section rendering). For value tags, they are treated as
text resp. numbers.

[subsection LAMBDAS]
Context values that are a Tcl list with the first element being the lambda prefix (usually "Λtcl")
are treated as lambdas: the second list element is evaluated - for section tags, a variable "arg"
is supplied to the lambda containing the verbatim section template content. The result is treated
as it was a context value itself.

[section "LAMBDA-UNSAFE SECTIONS"]
These are ordinary sections with an lambda unsafe marker (usually "λtcl") on start of their context.
Lambdas within those sections are always substituted from the context [emph outside] the section.
This makes it safe to use programmer defined lambdas mixed with user content. The lambda unsafe marker
is removed for simple list contexts so it doesn't interfere with processing iterator sections.

[para]
[emph "Lambda-unsafe section"]
[example_begin]
set context {safelambda {Λtcl {expr [lb]join $arg *[rb]}} unsafe {
	λtcl false userdata {Λtcl {return "I do evil things with your $arg"}}}}
set template {{{#unsafe}}{{#userdata}}1 2 3 4 5 6{{/userdata}}|{{#safelambda}}1 2 3 4 5 6{{/safelambda}}{{/unsafe}}}
::mustache::mustache $template $context
[example_end]
[para]
The "false" after the λtcl unsafe marker is needed only to keep the "key value key value" rhythm
of the context dict intact. The value associated with the key λtcl is ignored.

[para]
[emph "Lambda-unsafe iterator section"]
[example_begin]
set userdata {nice nicetoo Λtcl {return "I do evil things"}}
set context [lb]dict create unsafe [lb]concat λtcl $userdata[rb][rb]
set template {"{{#unsafe}}{{.}}|{{/unsafe}}"}
::mustache::mustache $template $context
[example_end]
[section EXAMPLES]
See the [uri examples.tcl] file in the installation directory or at[nl]
[uri https://github.com/ianka/mustache.tcl/blob/master/examples.tcl].
[manpage_end]
}

foreach {format ending} {html html nroff n} {
	::doctools::new mustache.$ending -format $format
	set fd [open "mustache.$ending" w+]
	puts $fd [mustache.$ending format $data]
	close $fd
}
