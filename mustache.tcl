#!/opt/ActiveTcl-8.6/bin/tclsh8.6

## Basic mustache:
## {{!comment}} - a comment
## {{item}} - substitute "item" (HTML escaped)
## {{{item}}} - substitute "item" (non-escaped)
## {{&item}}} - substitute "item" (non-escaped)
## {{#list}} - start substitute section with "list"
## {{^list}} - start "inverted" substitute section with "list"
## {{/list}} - end substitute section with "list"
## {{>template}} - include another "template"
## {{=open close=}} - change "open" and close tags


namespace eval ::mustache {
	set HtmlEscapeMap [dict create "&" "&amp;" "<" "&lt;" ">" "&gt;" "\"" "&quot;" "'" "&#39;"]

	proc escapeHtml {html} {
		subst [regsub -all {&(?!\w+;)|[<>"']} $html {[expr {[dict exists $::mustache::HtmlEscapeMap {&}]?[dict get $::mustache::HtmlEscapeMap {&}]:{&}}]}]
		#"
	}

	set openTag "\{\{"
	set closeTag "\}\}"

	proc compile {part context {frame {}} {output {}}} {
		## Get open index of next tag.
		set openindex [string first $::mustache::openTag $part]

		## Break tailcall when no new tag is found.
		if {$openindex==-1} {
			append output $part
			return [list $output {}]
		}

		## Copy verbatim text up to next tag to output.
		append output [string range $part 0 $openindex-1]

		## Get close index of tag.
		set closeindex [string first $::mustache::closeTag $part $openindex]
		set openlength [expr [string length $::mustache::openTag]+1]
		set closelength [string length $::mustache::closeTag]

		## Get command by tag type.
		switch -- [string index $part $openindex+2] {
			"\{" { incr closelength ; set command substitute ; set escape 0 }
			"!" { set command comment }
			"&" { set command substitute ; set escape 0 }
			"#" { set command startSection }
			"^" { set command startInvertedSection }
			"/" { set command endSection }
			">" { set command includeTemplate }
			"=" { set command setDelimiters }
			default { incr openlength -1 ; set command substitute ; set escape 1 }
		}

		## Get tag parameter.
		set parameter [string range $part $openindex+$openlength $closeindex-1]

		## Get tail.
		set tail [string range $part $closeindex+$closelength end]

		## Switch by command.
		switch -- $command {
			comment {}
			substitute {
				## Start with current frame.
				set thisframe $frame
				while true {
					## Check whether the parameter is defined in this frame.
					if {[dict exists $context {*}$thisframe $parameter]} {
						## Yes. Substitute in output. Escape if neccessary.
						if {$escape} {
							append output [escapeHtml [dict get $context {*}$thisframe $parameter]]
						} else {
							append output [dict get $context {*}$thisframe $parameter]
						}

						## Break.
						break
					} else {
						## No. Break if we are already in top frame.
						if {$thisframe eq {}} break
						
						## Check parent frame.
						set thisframe [lrange $thisframe 0 end-1]
					}
				}
			}
			startSection {
				## Check for existing key.
				set newframe [concat $frame $parameter]
				if {[dict exists $context {*}$newframe]} {
					set values [dict get $context {*}$newframe]

					## Skip silently if the values is false or an empty list.
					if {([string is boolean -strict $values] && !$values) || ($values eq {})} {
						foreach {dummy tail} [::mustache::compile $tail $context $newframe] {}
					} else {
						## Otherwise loop over list.
						foreach value $values {
							## Replace variant context by a single instance of it
							set newcontext $context
							dict set newcontext {*}$newframe $value

							## Call recursive, get new tail.
							foreach {sectionoutput newtail} [::mustache::compile $tail $newcontext $newframe] {}
							append output $sectionoutput
						}

						## Update tail to skip the section in this level.
						set tail $newtail
					}
				} else {
					## Key nonexistant. Skip silently over the section.
					foreach {dummy tail} [::mustache::compile $tail $context $newframe] {}
				}
			}
			startInvertedSection {
			}
			endSection {
				## Break recursion if parameter matches innermost frame.
				if {$parameter eq [lindex $frame end]} {
					return [list $output $tail]
				}
			}
		}

		## Tailcall with remainder of part, no iterator, current frame and current output.
		tailcall ::mustache::compile $tail $context $frame $output
	}


	## Convenience proc: throw away tail.
	proc mustache {part values} {lindex [::mustache::compile $part $values] 0}
}


puts [mustache::mustache {

<h1>Stadt, Land, Fluss</h1>
<table><colgroup><col span="3"></colgroup>
	<tr><th>Stadt</th><th>Land</th><th>Fluss</th><th>Nachbarn</th></tr>
{{#zeilen}}	<tr>{{! Macht gar nix}}<td>{{name}}-{{stadt}}</td><td>{{land}}</td><td>{{fluss}}</td><td><ol>{{#nachbarn}}<li>{{name}}-{{aber}}</li>{{/nachbarn}}</ol></td></tr>
{{/zeilen}}</table>
} {
name "blub"
aber "aber"
zeilen {
	{stadt "Bremen" land "Deutschland" fluss "Weser" aber "foo" nachbarn {{name "Niedersachsen"}}}
	{stadt "Paris" land "Frankreich" fluss "Seine" nachbarn {{name "Spanien"} {name "Andorra"} {name "Italien"} {name "Schweiz"} {name "Deutschland"} {name "Luxemburg"} {name "Belgien"} {name "Niederlande"}}}
	{stadt "London" land "Großbritannien" fluss "Themse" nachbarn 0}
}}]


