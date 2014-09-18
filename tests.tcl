#!/usr/bin/tclsh
##
## tests.tcl - a test script for mustache.tcl using the original mustache
## test suite from https://github.com/mustache/spec/tree/master/specs
##

package require mustache
package require yaml


## Helper procs. 
proc underline {string char} {
	return $string\n[string repeat $char [string length $string]]
}

## Do the tests of a single test file.
proc testFile {name} {
	set fd [open $name r]

	## Load test content.
	set tests [::yaml::yaml2dict [read $fd]]

	## Print overview when all tests should be performed.
	if {[lindex $::argv 0] eq {}} {
		puts \n[underline "Test file $name:" =]\n[dict get $tests overview]\n
	}

	## Go through all tests.
	foreach test [dict get $tests tests] {
		## Increment test counter
		incr ::counter

		## Ignore test if a special test number should be performed and this isn't it.
		if {[lindex $::argv 0] ni [list {} $::counter]} continue

		## Setup partials.
		if {[dict exists $test partials]} {
			foreach {partial ptemplate} [dict get $test partials] {
				set $partial $ptemplate
			}
		}

		## Do the test.
		set result [::mustache::mustache [dict get $test template] [dict get $test data]]

		## Remove partials.
		if {[dict exists $test partials]} {
			foreach {partial dummy} [dict get $test partials] {
				unset $partial
			}
		}

		## Report.
		if {$result eq [dict get $test expected]} {
			puts "[format %3d $::counter]: \[passed\] [dict get $test name] ([dict get $test desc])"
			incr ::passed
		} else {
			puts "[format %3d $::counter]: \[failed\] [dict get $test name] ([dict get $test desc])"
			puts "Template: \"[string map {" " "."} [dict get $test template]]\""
			puts "Data: [dict get $test data]"
			if {[dict exists $test partials]} {
				puts "Partials: [dict get $test partials]"
			}
			puts "Expected: \"[string map {" " "."} [dict get $test expected]]\""
			puts "Result: \"[string map {" " "."} $result]\""
		}	
		
	}

	close $fd
}


## Go trough all tests.
set counter 0
set passed 0
foreach filename [glob [file join tests *.yml]] {
	testFile $filename
}

puts "\n[underline "Result:" =]\n$passed of $counter tests passed."
