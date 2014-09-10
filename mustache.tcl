##
## mustache.tcl - an implementation of the mustache templating language in tcl.
## See https://github.com/mustache for further information about mustache.
##
## (C)2014 by Jan Kandziora <jjj@gmx.de>
##
## You may use, copy, distibute, and modify this software under the terms of
## the GNU General Public License(GPL), Version 2. See file COPYING for details.
##


namespace eval ::mustache {
	## Helpers.
	set HtmlEscapeMap [dict create "&" "&amp;" "<" "&lt;" ">" "&gt;" "\"" "&quot;" "'" "&#39;"]

	proc escapeHtml {html} {
		subst [regsub -all {&(?!\w+;)|[<>"']} $html {[expr {[dict exists $::mustache::HtmlEscapeMap {&}]?[dict get $::mustache::HtmlEscapeMap {&}]:{&}}]}]
		#"
	}

	## Main template compiler.
	proc compile {tail context {toplevel 0} {frame {}} {opendelimiter "\{\{"} {closedelimiter "\}\}"} {input {}} {output {}}} {
		set iteratorpassed 0

		## Loop over content.
		while true {
			## Get open index of next tag.
			set openindex [string first $opendelimiter $tail]

			## Break loop when no new tag is found.
			if {$openindex==-1} {
				append input $tail
				append output $tail
				return [list $input $output {} 0]
			}

			## Copy verbatim text up to next tag to input.
			append input [string range $tail 0 $openindex-1]

			## Get pre-tag content.
			set head [string range $tail 0 $openindex-1]

			## Get close index of tag.
			set openlength [expr [string length $opendelimiter]+1]
			set closeindex [string first $closedelimiter $tail $openindex+$openlength]
			set closelength [string length $closedelimiter]

			## Get command by tag type.
			switch -- [string index $tail $openindex+[string length $opendelimiter]] {
				"\{" { incr closelength ; set command substitute ; set escape 0 }
				"!" { set command comment }
				"&" { set command substitute ; set escape 0 }
				"." { set command iterator ; set escape 1 ; set iteratorpassed 1 }
				"#" { set command startSection }
				"^" { set command startInvertedSection }
				"/" { set command endSection }
				">" { set command includePartial }
				"=" { set command setDelimiters }
				default { incr openlength -1 ; set command substitute ; set escape 1 }
			}

			## Add verbatim tag to input, if not endSection.
			if {$command ne {endSection}} {
				append input [string range $tail $openindex [expr $closeindex+$closelength-1]]
			}

			## Get tag parameter.
			set parameter [string trim [string range $tail $openindex+$openlength $closeindex-1]]
	#puts "command:$command<<<"
	#puts "parameter:$openindex,$openlength,$closeindex,$parameter<<<"

			## Remove standalone blanks from head for some tags.
			if {$command ne {substitute}} {
				set standalone [expr {[regsub {^[[:blank:]]*$} $head {} head]|[regsub {\n[[:blank:]]*$} $head "\n" head]}]
  		} else {
				set standalone 0
			}

			## Append head to output.
			append output $head

			## Get tail.
			set tail [string range $tail $closeindex+$closelength end]

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
						## Split up the parameter in dotted sections.
						set parameter [split $parameter .]

						## Check whether the parameter base is defined in this frame.
						if {[dict exists $context {*}$thisframe [lindex $parameter 0]]} {
							## Yes. Break if the full key doesn't exist.
							if {![dict exists $context {*}$thisframe {*}$parameter]} break

							## Get value.
							set value [dict get $context {*}$thisframe {*}$parameter]

							## Treat doubles as numbers.
							if {[string is double -strict $value]} {
								set value [expr $value]
							}

							## Substitute in output, escape if neccessary.
							if {$escape} {
								append output [escapeHtml $value]
							} else {
								append output $value
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
				iterator {
					## Take whole frame content as value.
					set value [dict get $context {*}$frame]

					## Treat doubles as numbers.
					if {[string is double -strict $value]} {
						set value [expr $value]
					}

					## Substitute in output, escape if neccessary.
					if {$escape} {
						append output [escapeHtml $value]
					} else {
						append output $value
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
								foreach {dummy1 dummy2 tail dummy3} [::mustache::compile $tail $context $toplevel $newframe] {}
							} else {
								## Check for values is boolean true
								if {([string is boolean -strict $values] && $values)} {
									## Render section in current frame.
									foreach {dummy1 sectionoutput tail dummy2} [::mustache::compile $tail $context $toplevel $frame $opendelimiter $closedelimiter] {}
									append output $sectionoutput
								} else {
									## Check for lambda
									## (section value is just a single string value)
									if {[llength $values] == 1} {
										## Feed raw section into lambda.
										foreach {sectioninput dummy1 tail dummy2} [::mustache::compile $tail $context $toplevel $newframe $opendelimiter $closedelimiter] {}
										append output [$values $sectioninput $context $frame]
									} else {
										## Check for simple list vs. list of lists.
										## (section value is a list of key/value pairs)
										## WARNING: keys with whitespace in it are not allowed to
										## make it possible to detect list of lists.
										if {[llength [lindex $values 0]] == 1} {
											## Simple list.
											## Replace variant context by a single instance of it
											set newcontext $context
											dict set newcontext {*}$newframe $values

											## Call recursive, get new tail.
											foreach {dummy sectionoutput newtail iterator} [::mustache::compile $tail $newcontext $toplevel $newframe $opendelimiter $closedelimiter] {}

											## Check if iterator has been passed in the section.
											if {!$iterator} {
												## No. Section output is ok.
												append output $sectionoutput
											} else {
												## Yes. Throw away last result, try again with iterator context.
												foreach value $values {
													## Replace variant context by a single instance of it.
													set newcontext $context
													dict set newcontext {*}$newframe $value

													## Call recursive, get new tail.
													foreach {dummy1 sectionoutput newtail dummy2} [::mustache::compile $tail $newcontext $toplevel $newframe $opendelimiter $closedelimiter] {}
													append output $sectionoutput
												}
											}

											## Update tail to skip the section in this level.
											set tail $newtail
										} else {
											## Otherwise loop over list.
											foreach value $values {
												## Replace variant context by a single instance of it.
												set newcontext $context
												dict set newcontext {*}$newframe $value

												## Call recursive, get new tail.
												foreach {dummy1 sectionoutput newtail dummy2} [::mustache::compile $tail $newcontext $toplevel $newframe $opendelimiter $closedelimiter] {}
												append output $sectionoutput
											}

											## Update tail to skip the section in this level.
											set tail $newtail
										}
									}	
								}	
							}

							## Break
							break
						} else {
							## No. Break if we are already in top frame.
							if {$thisframe eq {}} {
								## Key nonexistant. Skip silently over the section.
								foreach {dummy1 dummy2 tail dummy3} [::mustache::compile $tail $context $toplevel $newframe] {}
						
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
							foreach {dummy1 sectionoutput tail dummy2} [::mustache::compile $tail $context $toplevel $newframe $opendelimiter $closedelimiter] {}
							append output $sectionoutput
						} else {
							## Key is a valid list. Skip silently over the section.
							foreach {dummy1 dummy2 tail dummy3} [::mustache::compile $tail $context $toplevel $newframe] {}
						}
					} else {
						## Key doesn't exist. Render once. 
						## Call recursive, get new tail.
						foreach {dummy1 sectionoutput tail dummy2} [::mustache::compile $tail $context $toplevel $newframe $opendelimiter $closedelimiter] {}
						append output $sectionoutput
					}
				}
				endSection {
					## Break recursion if parameter matches innermost frame.
					if {$parameter eq [lindex $frame end]} {
						return [list $input $output $tail $iteratorpassed]
					}
				}
				includePartial {
					## Compile a partial from a variable.
					upvar #$toplevel $parameter partial
					foreach {sectioninput sectionoutput dummy1 dummy2} [::mustache::compile $partial $context $toplevel $frame] {}
					append output $sectionoutput
				}
				setDelimiters {
					## Set tag delimiters.
					set opendelimiter [lindex [split [string range $parameter 0 end-1] { }] 0]
					set closedelimiter [lindex [split [string range $parameter 0 end-1] { }] 1]
				}
			}
		}
		}


	## Main proc.
	proc mustache {template values {frame {}}} {
		lindex [::mustache::compile $template $values [expr [info level]-1] $frame] 1
	}
}


## All ok, actually provide this package.
package provide mustache 1.0

