#!/opt/ActiveTcl-8.6/bin/tclsh8.6

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


## Please note the mustache.tcl package makes use of the new tailcall
## feature of Tcl-8.6, which means you need at least that Tcl version.

## Yes, we require this package. (^_^);
package require mustache


## Just a separator.
proc sep {} {puts [string repeat = 80]}


## A simple example. Take a piece of HTML and fill in the gaps with
## data from the templates. Note the comment and the automatic HTML
## escaping.
set text {
	<h1>Dear {{firstname}},{{! This is a comment}}</h1>
	<p>Best wishes to your {{age}} birthday.</p>
	<h2>{{sender}}</h2>
}
set data [dict create firstname "Fred" age "40th" sender "Greg & Tina"]

puts [::mustache::mustache $text $data]
sep


## Sometimes it's required to use different tag delimiters. These can
## be switched everywhere in the template. Tag names are trimmed for
## spaces, which comes in handy here.
set text {{{=<% %>=}}    {{<% name %>}} is awesome.
<%={{ }}=%>    {{name}} is still awesome.}
set data [dict create name "Fred"]

puts [::mustache::mustache $text $data]
sep


## Usually we want automatic HTML escaping of data.
## But not if it's escaped already. 
set text {Be as bold as {{{name}}}, not {{name}}. Or {{&name}}, this works, too.}
set data [dict create name "<strong>Greg</strong>"]

puts [::mustache::mustache $text $data]
sep


## The interesting part of mustache is iteration.
## You can easily contruct formatted lists from dictionaries. More, if a value
## isn't defined, all dictionary levels above are consulted to get the value.
## If all fails, nothing is rendered.
set text {<h1>Adressbook</h1>
<table>
	<tr><th>Name</th><th>Firstname</th><th>Phone</th></tr>
{{#people}}	<tr><td>{{name}}</td><td>{{firstname}}</td><td>{{phone}}</td></tr>
{{/people}}</table>}
set data [dict create \
	phone "unknown" \
	people [list \
		[dict create name "Hanson" firstname "Fred" phone 555-123] \
		[dict create name "Miller" firstname "Karen"] \
		[dict create name "DeMarco" firstname "Greg" phone 129-182] \
	] \
]

puts [::mustache::mustache $text $data]
sep


## There is another way to render wild-card entries which is useful for lists.
## The following example employs both. See the {{^phonenumers}} tag.
set text {<h1>Adressbook</h1>
<table>
	<tr><th>Name</th><th>Firstname</th><th>Phone</th></tr>
{{#people}}	<tr><td>{{name}}</td><td>{{firstname}}</td><td><ul>{{#phonenumbers}}<li>{{type}}: {{phone}}</li>{{/phonenumbers}}{{^phonenumbers}}<li>has no phone!</li>{{/phonenumbers}}</ul></td></tr>
{{/people}}</table>}
set data {
	phone "missing!"
	people {
		{name "Hanson" firstname "Fred" phonenumbers {{type home phone 555-123} {type work} {type mobile phone 333-122}}}
		{name "Miller" firstname "Karen" phonenumbers {}}
		{name "DeMarco" firstname "Greg" phonenumbers {{type work phone 129-182}}}
	}
}

puts [::mustache::mustache $text $data]
sep


## A useful template can be re-used several times in one or multiple templates
## by creating a partial from it. The context is automatically applied. Partial
## names are mapped to variables in the current level.
proc partialexample {} {
	set linepartial {<tr><td>{{name}}</td><td>{{firstname}}</td><td>{{>phonepartial}}</td></tr>}
	set phonepartial {<ul>{{#phonenumbers}}<li>{{type}}: {{phone}}</li>{{/phonenumbers}}{{^phonenumbers}}<li>has no phone!</li>{{/phonenumbers}}</ul>}
	set text {<h1>Adressbook</h1>
<table>
	<tr><th>Name</th><th>Firstname</th><th>Phone</th></tr>
{{#staff}}	{{>linepartial}}
{{/staff}}	<tr><td colspan="3">Below are customers!</td></tr>
{{#customers}}	{{>linepartial}}
{{/customers}}</table>
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

	puts [::mustache::mustache $text $data]
	sep
}

partialexample


##


exit





set ::keine {{{keine}}}
set ::nachbarn {<ol>{{#nachbarn}}<li>{{name}}-{{aber}}</li>{{/nachbarn}}{{^nachbarn}}<li>{{>keine}}</li>{{/nachbarn}}</ol>}

puts [::mustache::mustache {

<h1>Stadt, Land, Fluss</h1>
<table><colgroup><col span="3"></colgroup>
	<tr><th>Stadt</th><th>Land</th><th>Fluss</th><th>Nachbarn</th></tr>
{{#zeilen}}	<tr>{{! Macht gar nix}}<td>{{name}}-{{stadt}}</td><td>{{land}}</td><td>{{fluss}}</td><td>{{>nachbarn}}</td></tr>
{{/zeilen}}</table>
{{#wrapped}}
Mein Name ist {{name}}. Ich weiß bescheid.
{{>nachbarn}}
{{/wrapped}}

} {
keine "nada"
name "Hase"
aber "aber"
wrapped {::mustache::mustache}
nachbarn {{name "Hans"} {name "Walter"}}
zeilen {
	{stadt "Bremen" land "Deutschland" fluss "Weser" aber "foo" nachbarn {{name "Niedersachsen"}}}
	{stadt "London" land "Großbritannien" fluss "Themse"}
	{stadt "Paris" land "Frankreich" fluss "Seine" nachbarn {{name "Spanien"} {name "Andorra"} {name "Italien"} {name "Schweiz"} {name "Deutschland"} {name "Luxemburg"} {name "Belgien"} {name "Niederlande"}}}
}}]


