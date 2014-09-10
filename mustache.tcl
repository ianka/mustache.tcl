##
## mustache.tcl - an implementation of the mustache templating language in tcl.
## See https://github.com/mustache for further information about mustache.
##
## (C)2014 by Jan Kandziora <jjj@gmx.de>
##
## You may use, copy, distibute, and modify this software under the terms of
## the GNU General Public License(GPL), Version 2. See file COPYING for details.
##


## Needs at least Tcl 8.6 because of tailcall.
package require Tcl 8.6-


namespace eval ::mustache {
	## Helpers.
	set HtmlEscapeMap [dict create "&" "&amp;" "<" "&lt;" ">" "&gt;" "\"" "&quot;" "'" "&#39;"]

	proc escapeHtml {html} {
		subst [regsub -all {&(?!\w+;)|[<>"']} $html {[expr {[dict exists $::mustache::HtmlEscapeMap {&}]?[dict get $::mustache::HtmlEscapeMap {&}]:{&}}]}]
		#"
	}

	## Main template compiler.
	proc compile {part context {toplevel 0} {frame {}} {input {}} {output {}}} {
		## Get open index of next tag.
		set openindex [string first $::mustache::openTag $part]

		## Break tailcall when no new tag is found.
		if {$openindex==-1} {
			append input $part
			append output $part
			return [list $input $output {}]
		}

		## Copy verbatim text up to next tag to input.
		append input [string range $part 0 $openindex-1]

		## Get pre-tag content.
		set head [string range $part 0 $openindex-1]

		## Get close index of tag.
		set openlength [expr [string length $::mustache::openTag]+1]
		set closeindex [string first $::mustache::closeTag $part $openindex+$openlength]
		set closelength [string length $::mustache::closeTag]

		## Get command by tag type.
		switch -- [string index $part $openindex+[string length $::mustache::openTag]] {
			"\{" { incr closelength ; set command substitute ; set escape 0 }
			"!" { set command comment }
			"&" { set command substitute ; set escape 0 }
			"#" { set command startSection }
			"^" { set command startInvertedSection }
			"/" { set command endSection }
			">" { set command includePartial }
			"=" { set command setDelimiters }
			default { incr openlength -1 ; set command substitute ; set escape 1 }
		}

		## Add verbatim tag to input, if not endSection.
		if {$command ne {endSection}} {
			append input [string range $part $openindex [expr $closeindex+$closelength-1]]
		}

		## Get tag parameter.
		set parameter [string trim [string range $part $openindex+$openlength $closeindex-1]]
#puts "command:$command<<<"
#puts "parameter:$openindex,$openlength,$closeindex,$parameter<<<"

		## Remove standalone blanks from head for some tags.
		if {$command ne {substitute}} {
			set standalone [regsub -line {^[[:blank:]]*$} $head {} head]
		} else {
			set standalone 0
		}

		## Append head to output.
		append output $head

		## Get tail.
		set tail [string range $part $closeindex+$closelength end]

		## Remove trailing blanks and newline after standalone tag.
		if {$standalone} {
			regsub {^[[:blank:]]*\r?\n} $tail {} tail
		}

		## Switch by command.
		switch -- $command {
			comment {
			}
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
				## Start with current frame.
				set thisframe $frame
				while true {
					## Check for existing key.
					set newframe [concat $thisframe $parameter]
#puts stderr "thisframe:$thisframe<<<"
#puts stderr "newframe:$newframe<<<"
					if {[dict exists $context {*}$newframe]} {
						set values [dict get $context {*}$newframe]

						## Skip silently if the values is boolean false or an empty list.
						if {([string is boolean -strict $values] && !$values) || ($values eq {})} {
							foreach {dummy1 dummy2 tail} [::mustache::compile $tail $context $toplevel $newframe] {}
						} else {
							## Check for values is boolean true
							if {([string is boolean -strict $values] && $values)} {
								## Render section in current frame.
								foreach {dummy sectionoutput tail} [::mustache::compile $tail $context $toplevel $frame] {}
								append output $sectionoutput
							} else {
								## Check for lambda.
								if {[llength [lindex $values 0]] == 1} {
									## Feed raw section into lambda.
									foreach {sectioninput dummy tail} [::mustache::compile $tail $context $toplevel $newframe] {}
									append output [$values $sectioninput $context $frame]
								} else {
									## Otherwise loop over list.
									foreach value $values {
										## Replace variant context by a single instance of it
										set newcontext $context
										dict set newcontext {*}$newframe $value

										## Call recursive, get new tail.
										foreach {dummy sectionoutput newtail} [::mustache::compile $tail $newcontext $toplevel $newframe] {}
										append output $sectionoutput
									}

									## Update tail to skip the section in this level.
									set tail $newtail
								}
							}	
						}

						## Break
						break
					} else {
						## No. Break if we are already in top frame.
						if {$thisframe eq {}} {
							## Key nonexistant. Skip silently over the section.
							foreach {dummy1 dummy2 tail} [::mustache::compile $tail $context $toplevel $newframe] {}
					
							## Break.
							break
						}

						## Check parent frame.
						set thisframe [lrange $thisframe 0 end-1]
					}
				}
			}
			startInvertedSection {
				## Check for existing key.
				set newframe [concat $frame $parameter]
				if {[dict exists $context {*}$newframe]} {
					## Key exists.
					set values [dict get $context {*}$newframe]

					## Skip silently if the values is *not* false or an empty list.
					if {([string is boolean -strict $values] && !$values) || ($values eq {})} {
						## Key is false or empty list. Render once. 
						## Call recursive, get new tail.
						foreach {dummy sectionoutput tail} [::mustache::compile $tail $context $toplevel $newframe] {}
						append output $sectionoutput
					} else {
						## Key is a valid list. Skip silently over the section.
						foreach {dummy1 dummy2 tail} [::mustache::compile $tail $context $toplevel $newframe] {}
					}
				} else {
					## Key doesn't exist. Render once. 
					## Call recursive, get new tail.
					foreach {dummy sectionoutput tail} [::mustache::compile $tail $context $toplevel $newframe] {}
					append output $sectionoutput
				}
			}
			endSection {
				## Break recursion if parameter matches innermost frame.
				if {$parameter eq [lindex $frame end]} {
					return [list $input $output $tail]
				}
			}
			includePartial {
				## Compile a partial from a variable.
				upvar #$toplevel $parameter partial
				foreach {sectioninput sectionoutput dummy} [::mustache::compile $partial $context $toplevel $frame] {}
				append output $sectionoutput
			}
			setDelimiters {
				## Set tag delimiters.
				set ::mustache::openTag [lindex [split [string range $parameter 0 end-1] { }] 0]
				set ::mustache::closeTag [lindex [split [string range $parameter 0 end-1] { }] 1]
#puts stderr "openTag:$::mustache::openTag<<<"
#puts stderr "closeTag:$::mustache::closeTag<<<"
			}
		}

		## Tailcall for remaining content.
		tailcall ::mustache::compile $tail $context $toplevel $frame $input $output
	}


	## Main proc.
	proc mustache {template values {frame {}}} {
		set ::mustache::openTag "\{\{"
		set ::mustache::closeTag "\}\}"

		lindex [::mustache::compile $template $values [expr [info level]-1] $frame] 1
	}
}


## All ok, actually provide this package.
package provide mustache 1.0

