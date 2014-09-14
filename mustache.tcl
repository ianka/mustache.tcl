##
## mustache.tcl - an implementation of the mustache templating language in tcl.
## See https://github.com/mustache for further information about mustache.
##
## (C)2014 by Jan Kandziora <jjj@gmx.de>
##
## You may use, copy, distibute, and modify this software under the terms of
## the GNU General Public License(GPL), Version 2. See file COPYING for details.
##


## Require lambda package from tcllib.
## If you don't need mustache to support lambdas, you can leave this out.
package require lambda


namespace eval ::mustache {
	## Helpers.
	set HtmlEscapeMap [dict create "&" "&amp;" "<" "&lt;" ">" "&gt;" "\"" "&quot;" "'" "&#39;"]
	set LambdaPrefix "Λtcl"

	## Build search tree.
	proc searchtree {frame} {
		set thisframe $frame
		while {$thisframe ne {}} {
			lappend tree $thisframe
			set thisframe [lrange $thisframe 0 end-1]
		}
		lappend tree {} {*}[lreverse [lrange $frame 1 end]]
	}

	## Main template compiler.
	proc compile {tail context {toplevel 0} {frame {}} {standalone 1} {skippartials 0} {indent {}} {opendelimiter "\{\{"} {closedelimiter "\}\}"} {input {}} {output {}}} {
		set iteratorpassed 0
		set partialsindent $indent

		## Add indent to first output line.
		append output $indent

		## Loop over content.
		while true {
			## Get open index of next tag.
			set openindex [string first $opendelimiter $tail]

			## If standalone flag is cleared, look for next newline.
			if {!$standalone} {
				## Set standalone flag if a newline precedes the first tag.
				set newlineindex [string first "\n" $tail]
				set standalone [expr {($newlineindex>=0) && ($newlineindex < $openindex)} ]
			}

			## Get pre-tag content.
			if {$openindex>=0} {
				set head [string range $tail 0 $openindex-1]
			} else {
				set head $tail
			}

			## Copy verbatim text up to next tag to input.
			append input $head

			## Split head into lines for indentation.
			set headlist [split $head \n]

			## Break loop when no new tag is found.
			if {$openindex==-1} {
				## Indent pre-tag content.
				if {$headlist eq {}} {
					set head {}
				} elseif {[lindex $headlist end] ne {}} {
					set head [join $headlist "\n$indent"]
				} else {
					set head [join [lrange $headlist 0 end-1] "\n$indent"]\n
				}

				## Return with input and compiled output.
				append output $head
				return [list $input $output {} 0]
			}

			## Indent pre-tag content.
			set head [join $headlist "\n$indent"]

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

			## Get tail.
			set tail [string range $tail $closeindex+$closelength end]

			## Remove standalone flag for some occacions.
			if {$standalone && ($command eq {substitute})} {
				set standalone 0
			}
			if {$standalone && !([regsub {^[[:blank:]]*$} $head {} newhead]||[regsub {\n[[:blank:]]*$} $head "\n" newhead])} {
				set standalone 0
			}
			if {$standalone && !([regsub {^[[:blank:]]*\r?\n} $tail {} newtail]||[regsub {^[[:blank:]]*$} $tail {} newtail])} {
				set standalone 0
			}
	
			## If still standalone tag:
			if {$standalone} {
				## Set indent to use for partials.
				set partialsindent $indent[regsub {.*?([[:blank:]]*)$} $head {\1}]

				## Remove blanks and newline from head end and tail start for standalone tags.
				set head $newhead
				set tail $newtail
  		}

			## Append head to output.
			append output $head

			## Switch by command.
			switch -- $command {
				comment {
				}
				substitute {
					## Split up the parameter into dotted sections.
					set parameter [split $parameter .]

					## Check search tree.
					foreach thisframe [::mustache::searchtree $frame] {
						## Check whether the parameter base is defined in this frame.
						if {[dict exists $context {*}$thisframe [lindex $parameter 0]]} {
							## Yes. Break if the full key doesn't exist.
							if {![dict exists $context {*}$thisframe {*}$parameter]} break

							## Get value.
							set value [dict get $context {*}$thisframe {*}$parameter]

							## Check for lambda.
							if {![catch {dict get $value $::mustache::LambdaPrefix} body]} {
								## Lambda.
								foreach {dummy1 value dummy2 dummy3} [::mustache::compile [eval [::lambda {} $body]] $context $toplevel $frame $standalone $skippartials $indent] {}
							} {
								## Value. Treat doubles as numbers.
								if {[string is double -strict $value]} {
									set value [expr $value]
								}
							}

							## Substitute in output, escape if neccessary.
							if {$escape} {
								append output [string map $::mustache::HtmlEscapeMap $value]
							} else {
								append output $value
							}

							## Break.
							break
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
						append output [string map $::mustache::HtmlEscapeMap $value]
					} else {
						append output $value
					}
				}
				startSection {
					## Split up the parameter in dotted sections.
					set parameter [split $parameter .]

					## Start with new frame.
					set found 0
					set newframe [concat $frame $parameter]
					foreach thisframe [::mustache::searchtree [concat $frame [lrange $parameter 0 end-1]]] {
						## Check for existing key.
						if {![catch {dict get $context {*}$thisframe [lindex $parameter end]} values]} {
							## Context ok.
							set found 1
							## Skip silently if the values is boolean false or an empty list.
							if {([string is boolean -strict $values] && !$values) || ($values eq {})} {
								foreach {dummy1 dummy2 tail dummy3} [::mustache::compile $tail $context $toplevel $newframe $standalone 1] {}
							} else {
								## Check for values is boolean true
								if {([string is boolean -strict $values] && $values)} {
									## Render section in current frame.
									foreach {dummy1 sectionoutput tail dummy2} [::mustache::compile $tail $context $toplevel $frame $standalone $skippartials $indent $opendelimiter $closedelimiter] {}
									append output $sectionoutput
								} else {
									## Check for lambda.
									if {![catch {dict get $values $::mustache::LambdaPrefix} body]} {
										## Lambda. Get section input.
										foreach {sectioninput dummy1 tail dummy2} [::mustache::compile $tail $context $toplevel $newframe $standalone $skippartials $indent $opendelimiter $closedelimiter] {}

										## Evaluate lambda with section input.
										foreach {dummy1 value dummy2 dummy3} [::mustache::compile [eval [::lambda arg $body $sectioninput]] $context $toplevel $frame $standalone $skippartials $indent $opendelimiter $closedelimiter] {}

										## Substitute in output, escape.
										append output $value
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
											foreach {dummy sectionoutput newtail iterator} [::mustache::compile $tail $newcontext $toplevel $newframe $standalone $skippartials $indent $opendelimiter $closedelimiter] {}
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
													foreach {dummy1 sectionoutput newtail dummy2} [::mustache::compile $tail $newcontext $toplevel $newframe $standalone $skippartials $indent $opendelimiter $closedelimiter] {}
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
												foreach {dummy1 sectionoutput newtail dummy2} [::mustache::compile $tail $newcontext $toplevel $newframe $standalone $skippartials $indent $opendelimiter $closedelimiter] {}
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
						}	
					}

					## Skip silently over the section when no key was found.
					if {!$found} {
						foreach {dummy1 dummy2 tail dummy3} [::mustache::compile $tail $context $toplevel $newframe $standalone 1] {}
					}
				}
				startInvertedSection {
					## Split up the parameter in dotted sections.
					set parameter [split $parameter .]

					## Check for existing key.
					set newframe [concat $frame {*}$parameter]
					if {[dict exists $context {*}$newframe]} {
						## Key exists.
						set values [dict get $context {*}$newframe]

						## Skip silently if the values is *not* false or an empty list.
						if {([string is boolean -strict $values] && !$values) || ($values eq {})} {
							## Key is false or empty list. Render once. 
							## Call recursive, get new tail.
							foreach {dummy1 sectionoutput tail dummy2} [::mustache::compile $tail $context $toplevel $newframe $standalone $skippartials $indent $opendelimiter $closedelimiter] {}
							append output $sectionoutput
						} else {
							## Key is a valid list. Skip silently over the section.
							foreach {dummy1 dummy2 tail dummy3} [::mustache::compile $tail $context $toplevel $newframe $standalone 1] {}
						}
					} else {
						## Key doesn't exist. Render once. 
						## Call recursive, get new tail.
						foreach {dummy1 sectionoutput tail dummy2} [::mustache::compile $tail $context $toplevel $newframe $standalone $skippartials $indent $opendelimiter $closedelimiter] {}
						append output $sectionoutput
					}
				}
				endSection {
					## Split up the parameter in dotted sections.
					set parameter [split $parameter .]
					## Break recursion if parameter matches innermost frame.
					if {$parameter eq [lrange $frame end-[expr [llength $parameter]-1] end]} {
						return [list $input $output $tail $iteratorpassed]
					}
				}
				includePartial {
					## Skip partials when compiling is done only for skipping over a section.
					if {!$skippartials} {
						## Compile a partial from a variable.
						upvar #$toplevel $parameter partial
						if {[info exists partial]} {
							foreach {sectioninput sectionoutput dummy1 dummy2} [::mustache::compile $partial $context $toplevel $frame $standalone 0 $partialsindent] {}
							append output $sectionoutput
						}
					}
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
package provide mustache 1.1.2

