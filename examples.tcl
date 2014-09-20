#!/usr/bin/tclsh

##
## This is an example file for mustache.tcl by Jan Kandziora.
## See https://github.com/mustache for further information about mustache.
##

##
## Mustache syntax:
##
## {{!comment}} - a comment
## {{item}} - substitute "item" (HTML escaped)
## {{{item}}} - substitute "item" (non-escaped)
## {{&item}}} - substitute "item" (non-escaped)
## {{#list}} - start substitute section with "list"
## {{^list}} - start "inverted" substitute section with "list"
## {{/list}} - end substitute section with "list"
## {{>partial}} - include another "partial"
## {{=open close=}} - change "open" and "close" tags
##


## Use a safe interpreter with package loading mechanism for anything below.
set mustacheinterp [::safe::interpCreate]
puts [join [$mustacheinterp eval {
	## Yes, we require this package inside the safe interpreter. (^_^);
	package require mustache


	## Just a separator.
	proc sep {} {lappend ::safeoutput [string repeat = 80]}


	## A simple example. Take a piece of HTML and fill in the gaps with
	## data from the templates. Note the comment and the automatic HTML
	## escaping.
	set text {
	<h1>Dear {{firstname}},{{! This is a comment}}</h1>
	<p>Best wishes to your {{age}} birthday.</p>
	<h2>{{sender}}</h2>
}
	set data [dict create firstname "Fred" age "40th" sender "Greg & Tina"]

	lappend ::safeoutput [::mustache::mustache $text $data]
	sep


	## Sometimes it's required to use different tag delimiters. These can
	## be switched everywhere in the template. Tag names are trimmed for
	## spaces, which comes in handy here.
	set text {{{=<% %>=}}
{{<% name %>}} is awesome.
<%={{ }}=%>
{{name}} is still awesome.}
	set data [dict create name "Fred"]

	lappend ::safeoutput [::mustache::mustache $text $data]
	sep


	## Usually we want automatic HTML escaping of data.
	## But not if it's escaped already. 
	set text {Be as bold as {{{name}}}, not {{name}}. Or {{&name}}, this works, too.}
	set data [dict create name "<strong>Greg</strong>"]

	lappend ::safeoutput [::mustache::mustache $text $data]
	sep


	## The interesting part of mustache is iteration.
	## You can easily contruct formatted lists from dictionaries. More, if a value
	## isn't defined, all dictionary levels above are consulted to get the value.
	## If all fails, nothing is rendered.
	set text {<h1>Addressbook</h1>
<table>
	<tr><th>Name</th><th>Firstname</th><th>Phone</th></tr>
{{#people}}
	<tr><td>{{name}}</td><td>{{firstname}}</td><td>{{phone}}</td></tr>
{{/people}}
</table>}
	set data [dict create \
		phone "unknown" \
		people [list \
			[dict create name "Hanson" firstname "Fred" phone 555-123] \
			[dict create name "Miller" firstname "Karen"] \
			[dict create name "DeMarco" firstname "Greg" phone 129-182] \
		] \
	]

	lappend ::safeoutput [::mustache::mustache $text $data]
	sep


	## There is another way to render wild-card entries which is useful for lists.
	## The following example employs both. See the {{^phonenumers}} tag.
set text {<h1>Addressbook</h1>
<table>
	<tr><th>Name</th><th>Firstname</th><th>Phone</th></tr>
{{#people}}
	<tr><td>{{name}}</td><td>{{firstname}}</td>
		<td><ul>{{#phonenumbers}}
			<li>{{type}}: {{phone}}</li>{{/phonenumbers}}
		{{^phonenumbers}}
			<li>has no phone!</li>{{/phonenumbers}}
		</ul></td>
	</tr>
{{/people}}
</table>}
	set data {
		phone "missing!"
		people {
			{name "Hanson" firstname "Fred" phonenumbers {{type home phone 555-123} {type work} {type mobile phone 333-122}}}
			{name "Miller" firstname "Karen" phonenumbers {}}
			{name "DeMarco" firstname "Greg" phonenumbers {{type work phone 129-182}}}
		}
	}

	lappend ::safeoutput [::mustache::mustache $text $data]
	sep


	## A useful template can be re-used several times in one or multiple templates
	## by creating a partial from it. The context is automatically applied. Partial
	## names are mapped to variables in the current level. If no such variable exists,
	## the library dict variables given on the mustache call are consulted in order of
	## writing.
	set partiallib {
	phonepartial {
	<ul>
	{{#phonenumbers}}
		<li>{{type}}: {{phone}}</li>
	{{/phonenumbers}}
	{{^phonenumbers}}
		<li>has no phone!</li>
	{{/phonenumbers}}
	</ul>}
	linepartial {<tr><td>{{name}}</td><td>{{firstname}}</td><td>{{>phonepartial}}</td></tr>
}}

	proc partialexample {} {
		set linepartial {<tr><td>{{name}}</td><td>{{firstname}}</td><td class="phone">{{>phonepartial}}</td></tr>
}
		set text {<h1>Addressbook</h1>
<table>
	<tr><th>Name</th><th>Firstname</th><th>Phone</th></tr>
	{{#staff}}
	{{>linepartial}}
	{{/staff}}
	<tr><td colspan="3">Below are customers!</td></tr>
	{{#customers}}
	{{>linepartial}}
	{{/customers}}
</table>
}
		set data {
			phone "missing!"
			staff {
				{name "Hanson" firstname "Fred" phonenumbers {{type home phone 555-123} {type work} {type mobile phone 333-122}}}
				{name "Miller" firstname "Karen" phonenumbers {}}
				{name "DeMarco" firstname "Greg" phonenumbers {{type work phone 129-182}}}
			}	
			customers {
				{name "Kaeser" firstname "Mary" phonenumbers {{type home phone 555-111} {type mobile phone 333-862}}}
				{name "Floyd" firstname "Thomas" phonenumbers {{type mobile phone 333-163}}}
			}
		}

		lappend ::safeoutput [::mustache::mustache $text $data ::partiallib]
		sep
	}

	partialexample


	## Instead of lists, sections can also contain a lambda which is passed the
	## whole verbatim content of the section. If you don't need the section content
	## for the lambda, use it as a simple substitution. Note the lambda unsafe section.
	set text {<h1>Addressbook</h1>
{{#table}}
<table>
	<tr><th>Name</th><th>Firstname</th><th>Phone</th></tr>
{{#unsafe}}{{#people}}	<tr class="{{#lineclass}}white green blue{{/lineclass}}"><th>{{oddcounter}}</th><td>{{name}}</td><td>{{firstname}}</td><td>{{phone}}</td></tr>
{{/people}}{{/unsafe}}</table>
{{/table}}}
	set data [dict create \
		phone "unknown" \
		oddcounter {Λtcl {incr ::oddcounter 1 ; string repeat I $::oddcounter}} \
		lineclass {Λtcl {return "bar"}} \
		table [list  \
			lineclass {Λtcl {
				incr ::lineclass 0
				set result [lindex $arg $::lineclass]
				set ::lineclass [expr {($::lineclass+1)%[llength $arg]}]
				return $result
			}} \
			oddcounter {Λtcl {incr ::oddcounter 1 ; string repeat X $::oddcounter}} \
			unsafe [list \
				λtcl false \
				people [list \
					[dict create name "Hanson" firstname "Fred" phone 555-123] \
					[dict create name "Miller" firstname "Karen" phone {Λtcl {return "foo"}}] \
					[dict create name "DeMarco" firstname "Greg" phone 129-182] \
				] \
			] \
		] \
	]

	lappend ::safeoutput [::mustache::mustache $text $data]

}] "\n"]
