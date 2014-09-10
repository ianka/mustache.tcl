#!/opt/ActiveTcl-8.6/bin/tclsh8.6
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

	## Print overview.
	puts \n[underline "Test file $name:" =]\n[dict get $tests overview]\n

	## Go through all tests.
	foreach test [dict get $tests tests] {
		## Increment test counter
		incr ::counter

		## Do the test.
		set result [::mustache::mustache [dict get $test template] [dict get $test data]]

		## Report.
		if {$result eq [dict get $test expected]} {
			puts "[format %3d $::counter]: \[passed\] [dict get $test name] ([dict get $test desc])"
			incr ::passed
		} else {
			puts "[format %3d $::counter]: \[failed\] [dict get $test name] ([dict get $test desc])"
			puts "Template: [dict get $test template]"
			puts "Data: [dict get $test data]"
			puts "Expected: \"[dict get $test expected]\""
			puts "Result: \"$result\""
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