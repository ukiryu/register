YQ(1)			    General Commands Manual			 YQ(1)

NAME
       yq is a portable command-line data file processor

SYNOPSIS
       yq [eval/eval-all] [expression] files..

       eval/e - (default) Apply the expression to each document in each yaml
       file in sequence

       eval-all/ea - Loads all yaml documents of all yaml files and runs
       expression once

DESCRIPTION
       a lightweight and portable command-line data file processor.  yq uses
       jq <https://github.com/stedolan/jq> like syntax but works with yaml,
       json, xml, csv, properties and TOML files.  It doesn’t yet support
       everything jq does - but it does support the most common operations and
       functions, and more is being added continuously.

       This documentation is also available at
       https://mikefarah.gitbook.io/yq/ # QUICK GUIDE

   Read a value:
	      yq '.a.b[0].c' file.yaml

   Pipe from STDIN:
	      cat file.yaml | yq '.a.b[0].c'

   Update a yaml file, in place
	      yq -i '.a.b[0].c = "cool"' file.yaml

   Update using environment variables
	      NAME=mike yq -i '.a.b[0].c = strenv(NAME)' file.yaml

   Merge multiple files
	      yq ea '. as $item ireduce ({}; . * $item )' path/to/*.yml

       Note the use of ea to evaluate all files at once (instead of in
       sequence.)

   Multiple updates to a yaml file
	      yq -i '
		.a.b[0].c = "cool" |
		.x.y.z = "foobar" |
		.person.name = strenv(NAME)
	      ' file.yaml

       See the documentation <https://mikefarah.gitbook.io/yq/> for more.

KNOWN ISSUES / MISSING FEATURES
       • yq attempts to preserve comment positions and whitespace as much as
	 possible, but it does not handle all scenarios (see
	 https://github.com/go-yaml/yaml/tree/v3 for details)

       • Powershell has its own...opinions:
	 https://mikefarah.gitbook.io/yq/usage/tips-and-tricks#quotes-in-windows-powershell

BUGS / ISSUES / FEATURE REQUESTS
       Please visit the GitHub page https://github.com/mikefarah/yq/.

HOW IT WORKS
       In yq, expressions are made up of operators and pipes.  A context of
       nodes is passed through the expression, and each operation takes the
       context as input and returns a new context as output.  That output is
       piped in as input for the next operation in the expression.

       Let’s break down the process step by step using a diagram.  We’ll start
       with a single YAML document, apply an expression, and observe how the
       context changes at each step.

       Given a document like:

	      root:
		items:
		  - name: apple
		    type: fruit
		  - name: carrot
		    type: vegetable
		  - name: banana
		    type: fruit

       You can use dot notation to access nested structures.  For example, to
       access the name of the first item, you would use the expression
       .root.items[0].name, which would return apple.

       But lets see how we could find all the fruit under items

   Step 1: Initial Context
       The context starts at the root of the YAML document.  In this case, the
       entire document is the initial context.

	      root
	      └── items
		  ├── name: apple
		  │   type: fruit
		  ├── name: carrot
		  │   type: vegetable
		  └── name: banana
		      type: fruit

   Step 2: Splatting the Array
       Using the expression .root.items[], we “splat” the items array.	This
       means each element of the array becomes its own node in the context:

	      Node 1: { name: apple, type: fruit }
	      Node 2: { name: carrot, type: vegetable }
	      Node 3: { name: banana, type: fruit }

   Step 3: Filtering the Nodes
       Next, we apply a filter to select only the nodes where type is fruit.
       The expression .root.items[] | select(.type == "fruit") filters the
       nodes:

	      Filtered Node 1: { name: apple, type: fruit }
	      Filtered Node 2: { name: banana, type: fruit }

   Step 4: Extracting a Field
       Finally, we extract the name field from the filtered nodes using
       .root.items[] | select(.type == "fruit") | .name This results in:

	      apple
	      banana

   Simple assignment example
       Given a document like:

	      a: cat
	      b: dog

       with an expression:

	      .a = .b

       Like math expressions - operator precedence is important.

       The = operator takes two arguments, a lhs expression, which in this
       case is .a and rhs expression which is .b.

       It pipes the current, lets call it `root' context through the lhs
       expression of .a to return the node

	      cat

       Side note: this node holds not only its value `cat', but comments and
       metadata too, including path and parent information.

       The = operator then pipes the `root' context through the rhs expression
       of .b to return the node

	      dog

       Both sides have now been evaluated, so now the operator copies across
       the value from the RHS (.b) to the LHS (.a), and it returns the now
       updated context:

	      a: dog
	      b: dog

   Complex assignment, operator precedence rules
       Just like math expressions - yq expressions have an order of
       precedence.  The pipe | operator has a low order of precedence, so
       operators with higher precedence will get evaluated first.

       Most of the time, this is intuitively what you’d want, for instance .a
       = "cat" | .b = "dog" is effectively: (.a = "cat") | (.b = "dog").

       However, this is not always the case, particularly if you have a
       complex LHS or RHS expression, for instance if you want to select
       particular nodes to update.

       Lets say you had:

	      - name: bob
		fruit: apple
	      - name: sally
		fruit: orange

       Lets say you wanted to update the sally entry to have fruit: `mango'.
       The incorrect way to do that is: .[] | select(.name == "sally") |
       .fruit = "mango".

       Because | has a low operator precedence, this will be evaluated
       (incorrectly) as : (.[]) | (select(.name == "sally")) | (.fruit =
       "mango").  What you’ll see is only the updated segment returned:

	      name: sally
	      fruit: mango

       Important: To properly update this YAML, you must wrap the entire LHS
       in parentheses.	Think of it like using brackets in math to ensure the
       correct order of operations.  (.[] | select(.name == "sally") | .fruit)
       = "mango"

       Now that entire LHS expression is passed to the `assign' (=) operator,
       and the yaml is correctly updated and returned:

	      - name: bob
		fruit: apple
	      - name: sally
		fruit: mango

   Relative update (e.g. |=)
       There is another form of the = operator which we call the relative
       form.  It’s very similar to = but with one key difference when
       evaluating the RHS expression.

       In the plain form, we pass in the `root' level context to the RHS
       expression.  In relative form, we pass in each result of the LHS to the
       RHS expression.	Let’s go through an example.

       Given a document like:

	      a: 1
	      b: thing

       with an expression:

	      .a |= . + 1

       Similar to the = operator, |= takes two operands, the LHS and RHS.

       It pipes the current context (the whole document) through the LHS
       expression of .a to get the node value:

	      1

       Now it pipes that LHS context into the RHS expression . + 1 (whereas in
       the = plain form it piped the original document context into the RHS)
       to yield:

	      2

       The assignment operator then copies across the value from the RHS to
       the value on the LHS, and it returns the now updated `root' context:

	      a: 2
	      b: thing
	      ```# Add

	      Add behaves differently according to the type of the LHS:
	      * arrays: concatenate
	      * number scalars: arithmetic addition
	      * string scalars: concatenate
	      * maps: shallow merge (use the multiply operator (`*`) to deeply merge)

	      Use `+=` as a relative append assign for things like increment. Note that `.a += .x` is equivalent to running `.a = .a + .x`.

	      ## Concatenate arrays
	      Given a sample.yml file of:
	      ```yaml
	      a:
		- 1
		- 2
	      b:
		- 3
		- 4

       then

	      yq '.a + .b' sample.yml

       will output

	      - 1
	      - 2
	      - 3
	      - 4

   Concatenate to existing array
       Note that the styling of a is kept.

       Given a sample.yml file of:

	      a: [1,2]
	      b:
		- 3
		- 4

       then

	      yq '.a += .b' sample.yml

       will output

	      a: [1, 2, 3, 4]
	      b:
		- 3
		- 4

   Concatenate null to array
       Given a sample.yml file of:

	      a:
		- 1
		- 2

       then

	      yq '.a + null' sample.yml

       will output

	      - 1
	      - 2

   Append to existing array
       Note that the styling is copied from existing array elements

       Given a sample.yml file of:

	      a: ['dog']

       then

	      yq '.a += "cat"' sample.yml

       will output

	      a: ['dog', 'cat']

   Prepend to existing array
       Given a sample.yml file of:

	      a:
		- dog

       then

	      yq '.a = ["cat"] + .a' sample.yml

       will output

	      a:
		- cat
		- dog

   Add new object to array
       Given a sample.yml file of:

	      a:
		- dog: woof

       then

	      yq '.a + {"cat": "meow"}' sample.yml

       will output

	      - dog: woof
	      - cat: meow

   Relative append
       Given a sample.yml file of:

	      a:
		a1:
		  b:
		    - cat
		a2:
		  b:
		    - dog
		a3: {}

       then

	      yq '.a[].b += ["mouse"]' sample.yml

       will output

	      a:
		a1:
		  b:
		    - cat
		    - mouse
		a2:
		  b:
		    - dog
		    - mouse
		a3:
		  b:
		    - mouse

   String concatenation
       Given a sample.yml file of:

	      a: cat
	      b: meow

       then

	      yq '.a += .b' sample.yml

       will output

	      a: catmeow
	      b: meow

   Number addition - float
       If the lhs or rhs are floats then the expression will be calculated
       with floats.

       Given a sample.yml file of:

	      a: 3
	      b: 4.9

       then

	      yq '.a = .a + .b' sample.yml

       will output

	      a: 7.9
	      b: 4.9

   Number addition - int
       If both the lhs and rhs are ints then the expression will be calculated
       with ints.

       Given a sample.yml file of:

	      a: 3
	      b: 4

       then

	      yq '.a = .a + .b' sample.yml

       will output

	      a: 7
	      b: 4

   Increment numbers
       Given a sample.yml file of:

	      a: 3
	      b: 5

       then

	      yq '.[] += 1' sample.yml

       will output

	      a: 4
	      b: 6

   Date addition
       You can add durations to dates.	Assumes RFC3339 date time format, see
       date-time operators
       <https://mikefarah.gitbook.io/yq/operators/date-time-operators> for
       more information.

       Given a sample.yml file of:

	      a: 2021-01-01T00:00:00Z

       then

	      yq '.a += "3h10m"' sample.yml

       will output

	      a: 2021-01-01T03:10:00Z

   Date addition - custom format
       You can add durations to dates.	See date-time operators
       <https://mikefarah.gitbook.io/yq/operators/date-time-operators> for
       more information.

       Given a sample.yml file of:

	      a: Saturday, 15-Dec-01 at 2:59AM GMT

       then

	      yq 'with_dtf("Monday, 02-Jan-06 at 3:04PM MST", .a += "3h1m")' sample.yml

       will output

	      a: Saturday, 15-Dec-01 at 6:00AM GMT

   Add to null
       Adding to null simply returns the rhs

       Running

	      yq --null-input 'null + "cat"'

       will output

	      cat

   Add maps to shallow merge
       Adding objects together shallow merges them.  Use * to deeply merge.

       Given a sample.yml file of:

	      a:
		thing:
		  name: Astuff
		  value: x
		a1: cool
	      b:
		thing:
		  name: Bstuff
		  legs: 3
		b1: neat

       then

	      yq '.a += .b' sample.yml

       will output

	      a:
		thing:
		  name: Bstuff
		  legs: 3
		a1: cool
		b1: neat
	      b:
		thing:
		  name: Bstuff
		  legs: 3
		b1: neat

   Custom types: that are really strings
       When custom tags are encountered, yq will try to decode the underlying
       type.

       Given a sample.yml file of:

	      a: !horse cat
	      b: !goat _meow

       then

	      yq '.a += .b' sample.yml

       will output

	      a: !horse cat_meow
	      b: !goat _meow

   Custom types: that are really numbers
       When custom tags are encountered, yq will try to decode the underlying
       type.

       Given a sample.yml file of:

	      a: !horse 1.2
	      b: !goat 2.3

       then

	      yq '.a += .b' sample.yml

       will output

	      a: !horse 3.5
	      b: !goat 2.3

Alternative (Default value)
       This operator is used to provide alternative (or default) values when a
       particular expression is either null or false.

   LHS is defined
       Given a sample.yml file of:

	      a: bridge

       then

	      yq '.a // "hello"' sample.yml

       will output

	      bridge

   LHS is not defined
       Given a sample.yml file of:

	      {}

       then

	      yq '.a // "hello"' sample.yml

       will output

	      hello

   LHS is null
       Given a sample.yml file of:

	      a: ~

       then

	      yq '.a // "hello"' sample.yml

       will output

	      hello

   LHS is false
       Given a sample.yml file of:

	      a: false

       then

	      yq '.a // "hello"' sample.yml

       will output

	      hello

   RHS is an expression
       Given a sample.yml file of:

	      a: false
	      b: cat

       then

	      yq '.a // .b' sample.yml

       will output

	      cat

   Update or create - entity exists
       This initialises a if it’s not present

       Given a sample.yml file of:

	      a: 1

       then

	      yq '(.a // (.a = 0)) += 1' sample.yml

       will output

	      a: 2

   Update or create - entity does not exist
       This initialises a if it’s not present

       Given a sample.yml file of:

	      b: camel

       then

	      yq '(.a // (.a = 0)) += 1' sample.yml

       will output

	      b: camel
	      a: 1

Anchor and Alias Operators
       Use the alias and anchor operators to read and write yaml aliases and
       anchors.  The explode operator normalises a yaml file (dereference (or
       expands) aliases and remove anchor names).

       yq supports merge aliases (like <<: *blah) however this is no longer in
       the standard yaml spec (1.2) and so yq will automatically add the
       !!merge tag to these nodes as it is effectively a custom tag.

   NOTE –yaml-fix-merge-anchor-to-spec flag
       yq doesn’t merge anchors <<: to spec, in some circumstances it
       incorrectly overrides existing keys when the spec documents not to do
       that.

       To minimise disruption while still fixing the issue, a flag has been
       added to toggle this behaviour.	This will first default to false; and
       log warnings to users.  Then it will default to true (and still allow
       users to specify false if needed).

       This flag also enables advanced merging, like inline maps, as well as
       fixes to ensure when exploding a particular path, neighbours are not
       affect ed.

       Long story short, you should be setting this flag to true.

       See examples of the flag differences below, where LEGACY is with the
       flag off; and FIXED is with the flag on.

   Merge one map
       see https://yaml.org/type/merge.html

       Given a sample.yml file of:

	      - &CENTER
		x: 1
		y: 2
	      - &LEFT
		x: 0
		y: 2
	      - &BIG
		r: 10
	      - &SMALL
		r: 1
	      - !!merge <<: *CENTER
		r: 10

       then

	      yq '.[4] | explode(.)' sample.yml

       will output

	      x: 1
	      y: 2
	      r: 10

   Get anchor
       Given a sample.yml file of:

	      a: &billyBob cat

       then

	      yq '.a | anchor' sample.yml

       will output

	      billyBob

   Set anchor
       Given a sample.yml file of:

	      a: cat

       then

	      yq '.a anchor = "foobar"' sample.yml

       will output

	      a: &foobar cat

   Set anchor relatively using assign-update
       Given a sample.yml file of:

	      a:
		b: cat

       then

	      yq '.a anchor |= .b' sample.yml

       will output

	      a: &cat
		b: cat

   Get alias
       Given a sample.yml file of:

	      b: &billyBob meow
	      a: *billyBob

       then

	      yq '.a | alias' sample.yml

       will output

	      billyBob

   Set alias
       Given a sample.yml file of:

	      b: &meow purr
	      a: cat

       then

	      yq '.a alias = "meow"' sample.yml

       will output

	      b: &meow purr
	      a: *meow

   Set alias to blank does nothing
       Given a sample.yml file of:

	      b: &meow purr
	      a: cat

       then

	      yq '.a alias = ""' sample.yml

       will output

	      b: &meow purr
	      a: cat

   Set alias relatively using assign-update
       Given a sample.yml file of:

	      b: &meow purr
	      a:
		f: meow

       then

	      yq '.a alias |= .f' sample.yml

       will output

	      b: &meow purr
	      a: *meow

   Explode alias and anchor
       Given a sample.yml file of:

	      f:
		a: &a cat
		b: *a

       then

	      yq 'explode(.f)' sample.yml

       will output

	      f:
		a: cat
		b: cat

   Explode with no aliases or anchors
       Given a sample.yml file of:

	      a: mike

       then

	      yq 'explode(.a)' sample.yml

       will output

	      a: mike

   Explode with alias keys
       Given a sample.yml file of:

	      f:
		a: &a cat
		*a : b

       then

	      yq 'explode(.f)' sample.yml

       will output

	      f:
		a: cat
		cat: b

   Dereference and update a field
       Use explode with multiply to dereference an object

       Given a sample.yml file of:

	      item_value: &item_value
		value: true
	      thingOne:
		name: item_1
		!!merge <<: *item_value
	      thingTwo:
		name: item_2
		!!merge <<: *item_value

       then

	      yq '.thingOne |= (explode(.) | sort_keys(.)) * {"value": false}' sample.yml

       will output

	      item_value: &item_value
		value: true
	      thingOne:
		name: item_1
		value: false
	      thingTwo:
		name: item_2
		!!merge <<: *item_value

   LEGACY: Explode with merge anchors
       Caution: this is for when –yaml-fix-merge-anchor-to-spec=false; it’s
       not to YAML spec because the merge anchors incorrectly override the
       object values (foobarList.b is set to bar_b when it should still be
       foobarList_b).  Flag will default to true in late 2025

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq 'explode(.)' sample.yml

       will output

	      foo:
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar:
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: bar_b
		thing: foo_thing
		c: foobarList_c
		a: foo_a
	      foobar:
		c: foo_c
		a: foo_a
		thing: foobar_thing

   LEGACY: Merge multiple maps
       see https://yaml.org/type/merge.html.  This has the correct data, but
       the wrong key order; set –yaml-fix-merge-anchor-to-spec=true to fix the
       key order.

       Given a sample.yml file of:

	      - &CENTER
		x: 1
		y: 2
	      - &LEFT
		x: 0
		y: 2
	      - &BIG
		r: 10
	      - &SMALL
		r: 1
	      - !!merge <<:
		  - *CENTER
		  - *BIG

       then

	      yq '.[4] | explode(.)' sample.yml

       will output

	      r: 10
	      x: 1
	      y: 2

   LEGACY: Override
       see https://yaml.org/type/merge.html.  This has the correct data, but
       the wrong key order; set –yaml-fix-merge-anchor-to-spec=true to fix the
       key order.

       Given a sample.yml file of:

	      - &CENTER
		x: 1
		y: 2
	      - &LEFT
		x: 0
		y: 2
	      - &BIG
		r: 10
	      - &SMALL
		r: 1
	      - !!merge <<:
		  - *BIG
		  - *LEFT
		  - *SMALL
		x: 1

       then

	      yq '.[4] | explode(.)' sample.yml

       will output

	      r: 10
	      x: 1
	      y: 2

   FIXED: Explode with merge anchors
       Set --yaml-fix-merge-anchor-to-spec=true to get this correct merge
       behaviour (flag will default to true in late 2025).  Observe that
       foobarList.b property is still foobarList_b.

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq 'explode(.)' sample.yml

       will output

	      foo:
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar:
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		a: foo_a
		thing: foo_thing
		c: foobarList_c
	      foobar:
		c: foobar_c
		a: foo_a
		thing: foobar_thing

   FIXED: Merge multiple maps
       Set --yaml-fix-merge-anchor-to-spec=true to get this correct merge
       behaviour (flag will default to true in late 2025).  Taken from
       https://yaml.org/type/merge.html.  Same values as legacy, but with the
       correct key order.

       Given a sample.yml file of:

	      - &CENTER
		x: 1
		y: 2
	      - &LEFT
		x: 0
		y: 2
	      - &BIG
		r: 10
	      - &SMALL
		r: 1
	      - !!merge <<:
		  - *CENTER
		  - *BIG

       then

	      yq '.[4] | explode(.)' sample.yml

       will output

	      x: 1
	      y: 2
	      r: 10

   FIXED: Override
       Set --yaml-fix-merge-anchor-to-spec=true to get this correct merge
       behaviour (flag will default to true in late 2025).  Taken from
       https://yaml.org/type/merge.html.  Same values as legacy, but with the
       correct key order.

       Given a sample.yml file of:

	      - &CENTER
		x: 1
		y: 2
	      - &LEFT
		x: 0
		y: 2
	      - &BIG
		r: 10
	      - &SMALL
		r: 1
	      - !!merge <<:
		  - *BIG
		  - *LEFT
		  - *SMALL
		x: 1

       then

	      yq '.[4] | explode(.)' sample.yml

       will output

	      r: 10
	      y: 2
	      x: 1

   Exploding inline merge anchor
       Set --yaml-fix-merge-anchor-to-spec=true to get this correct merge
       behaviour (flag will default to true in late 2025).

       Given a sample.yml file of:

	      a:
		b: &b 42
	      !!merge <<:
		c: *b

       then

	      yq 'explode(.) | sort_keys(.)' sample.yml

       will output

	      a:
		b: 42
	      c: 42

Array to Map
       Use this operator to convert an array to..a map.  The indices are used
       as map keys, null values in the array are skipped over.

       Behind the scenes, this is implemented using reduce:

	      (.[] | select(. != null) ) as $i ireduce({}; .[$i | key] = $i)

   Simple example
       Given a sample.yml file of:

	      cool:
		- null
		- null
		- hello

       then

	      yq '.cool |= array_to_map' sample.yml

       will output

	      cool:
		2: hello

Assign (Update)
       This operator is used to update node values.  It can be used in either
       the:

   plain form: =
       Which will set the LHS node values equal to the RHS node values.  The
       RHS expression is run against the matching nodes in the pipeline.

   relative form: |=
       This will do a similar thing to the plain form, but the RHS expression
       is run with each LHS node as context.  This is useful for updating
       values based on old values, e.g. increment.

   Flags
       • c clobber custom tags

   Create yaml file
       Running

	      yq --null-input '.a.b = "cat" | .x = "frog"'

       will output

	      a:
		b: cat
	      x: frog

   Update node to be the child value
       Given a sample.yml file of:

	      a:
		b:
		  g: foof

       then

	      yq '.a |= .b' sample.yml

       will output

	      a:
		g: foof

   Double elements in an array
       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3

       then

	      yq '.[] |= . * 2' sample.yml

       will output

	      - 2
	      - 4
	      - 6

   Update node from another file
       Note this will also work when the second file is a scalar
       (string/number)

       Given a sample.yml file of:

	      a: apples

       And another sample another.yml file of:

	      b: bob

       then

	      yq eval-all 'select(fileIndex==0).a = select(fileIndex==1) | select(fileIndex==0)' sample.yml another.yml

       will output

	      a:
		b: bob

   Update node to be the sibling value
       Given a sample.yml file of:

	      a:
		b: child
	      b: sibling

       then

	      yq '.a = .b' sample.yml

       will output

	      a: sibling
	      b: sibling

   Updated multiple paths
       Given a sample.yml file of:

	      a: fieldA
	      b: fieldB
	      c: fieldC

       then

	      yq '(.a, .c) = "potato"' sample.yml

       will output

	      a: potato
	      b: fieldB
	      c: potato

   Update string value
       Given a sample.yml file of:

	      a:
		b: apple

       then

	      yq '.a.b = "frog"' sample.yml

       will output

	      a:
		b: frog

   Update string value via |=
       Note there is no difference between = and |= when the RHS is a scalar

       Given a sample.yml file of:

	      a:
		b: apple

       then

	      yq '.a.b |= "frog"' sample.yml

       will output

	      a:
		b: frog

   Update deeply selected results
       Note that the LHS is wrapped in brackets!  This is to ensure we don’t
       first filter out the yaml and then update the snippet.

       Given a sample.yml file of:

	      a:
		b: apple
		c: cactus

       then

	      yq '(.a[] | select(. == "apple")) = "frog"' sample.yml

       will output

	      a:
		b: frog
		c: cactus

   Update array values
       Given a sample.yml file of:

	      - candy
	      - apple
	      - sandy

       then

	      yq '(.[] | select(. == "*andy")) = "bogs"' sample.yml

       will output

	      - bogs
	      - apple
	      - bogs

   Update empty object
       Given a sample.yml file of:

	      {}

       then

	      yq '.a.b |= "bogs"' sample.yml

       will output

	      a:
		b: bogs

   Update node value that has an anchor
       Anchor will remain

       Given a sample.yml file of:

	      a: &cool cat

       then

	      yq '.a = "dog"' sample.yml

       will output

	      a: &cool dog

   Update empty object and array
       Given a sample.yml file of:

	      {}

       then

	      yq '.a.b.[0] |= "bogs"' sample.yml

       will output

	      a:
		b:
		  - bogs

   Custom types are maintained by default
       Given a sample.yml file of:

	      a: !cat meow
	      b: !dog woof

       then

	      yq '.a = .b' sample.yml

       will output

	      a: !cat woof
	      b: !dog woof

   Custom types: clobber
       Use the c option to clobber custom tags

       Given a sample.yml file of:

	      a: !cat meow
	      b: !dog woof

       then

	      yq '.a =c .b' sample.yml

       will output

	      a: !dog woof
	      b: !dog woof

Boolean Operators
       The or and and operators take two parameters and return a boolean
       result.

       not flips a boolean from true to false, or vice versa.

       any will return true if there are any true values in an array sequence,
       and all will return true if all elements in an array are true.

       any_c(condition) and all_c(condition) are like any and all but they
       take a condition expression that is used against each element to
       determine if it’s true.	Note: in jq you can simply pass a condition to
       any or all and it simply works - yq isn’t that clever..yet

       These are most commonly used with the select operator to filter
       particular nodes.

   Related Operators
       • equals / not equals (==, !=) operators here
	 <https://mikefarah.gitbook.io/yq/operators/equals>

       • comparison (>=, < etc) operators here
	 <https://mikefarah.gitbook.io/yq/operators/compare>

       • select operator here
	 <https://mikefarah.gitbook.io/yq/operators/select>

   or example
       Running

	      yq --null-input 'true or false'

       will output

	      true

   “yes” and “no” are strings
       In the yaml 1.2 standard, support for yes/no as booleans was dropped -
       they are now considered strings.  See `10.2.1.2.  Boolean' in
       https://yaml.org/spec/1.2.2/

       Given a sample.yml file of:

	      - yes
	      - no

       then

	      yq '.[] | tag' sample.yml

       will output

	      !!str
	      !!str

   and example
       Running

	      yq --null-input 'true and false'

       will output

	      false

   Matching nodes with select, equals and or
       Given a sample.yml file of:

	      - a: bird
		b: dog
	      - a: frog
		b: bird
	      - a: cat
		b: fly

       then

	      yq '[.[] | select(.a == "cat" or .b == "dog")]' sample.yml

       will output

	      - a: bird
		b: dog
	      - a: cat
		b: fly

   any returns true if any boolean in a given array is true
       Given a sample.yml file of:

	      - false
	      - true

       then

	      yq 'any' sample.yml

       will output

	      true

   any returns false for an empty array
       Given a sample.yml file of:

	      []

       then

	      yq 'any' sample.yml

       will output

	      false

   any_c returns true if any element in the array is true for the given
       condition.
       Given a sample.yml file of:

	      a:
		- rad
		- awesome
	      b:
		- meh
		- whatever

       then

	      yq '.[] |= any_c(. == "awesome")' sample.yml

       will output

	      a: true
	      b: false

   all returns true if all booleans in a given array are true
       Given a sample.yml file of:

	      - true
	      - true

       then

	      yq 'all' sample.yml

       will output

	      true

   all returns true for an empty array
       Given a sample.yml file of:

	      []

       then

	      yq 'all' sample.yml

       will output

	      true

   all_c returns true if all elements in the array are true for the given
       condition.
       Given a sample.yml file of:

	      a:
		- rad
		- awesome
	      b:
		- meh
		- 12

       then

	      yq '.[] |= all_c(tag == "!!str")' sample.yml

       will output

	      a: true
	      b: false

   Not true is false
       Running

	      yq --null-input 'true | not'

       will output

	      false

   Not false is true
       Running

	      yq --null-input 'false | not'

       will output

	      true

   String values considered to be true
       Running

	      yq --null-input '"cat" | not'

       will output

	      false

   Empty string value considered to be true
       Running

	      yq --null-input '"" | not'

       will output

	      false

   Numbers are considered to be true
       Running

	      yq --null-input '1 | not'

       will output

	      false

   Zero is considered to be true
       Running

	      yq --null-input '0 | not'

       will output

	      false

   Null is considered to be false
       Running

	      yq --null-input '~ | not'

       will output

	      true

Collect into Array
       This creates an array using the expression between the square brackets.

   Collect empty
       Running

	      yq --null-input '[]'

       will output

	      []

   Collect single
       Running

	      yq --null-input '["cat"]'

       will output

	      - cat

   Collect many
       Given a sample.yml file of:

	      a: cat
	      b: dog

       then

	      yq '[.a, .b]' sample.yml

       will output

	      - cat
	      - dog

Column
       Returns the column of the matching node.  Starts from 1, 0 indicates
       there was no column data.

       Column is the number of characters that precede that node on the line
       it starts.

   Returns column of value node
       Given a sample.yml file of:

	      a: cat
	      b: bob

       then

	      yq '.b | column' sample.yml

       will output

	      4

   Returns column of key node
       Pipe through the key operator to get the column of the key

       Given a sample.yml file of:

	      a: cat
	      b: bob

       then

	      yq '.b | key | column' sample.yml

       will output

	      1

   First column is 1
       Given a sample.yml file of:

	      a: cat

       then

	      yq '.a | key | column' sample.yml

       will output

	      1

   No column data is 0
       Running

	      yq --null-input '{"a": "new entry"} | column'

       will output

	      0

Comment Operators
       Use these comment operators to set or retrieve comments.  Note that
       line comments on maps/arrays are actually set on the key node as
       opposed to the value (map/array).  See below for examples.

       Like the = and |= assign operators, the same syntax applies when
       updating comments:

   plain form: =
       This will set the LHS nodes’ comments equal to the expression on the
       RHS.  The RHS is run against the matching nodes in the pipeline

   relative form: |=
       This is similar to the plain form, but it evaluates the RHS with each
       matching LHS node as context.  This is useful if you want to set the
       comments as a relative expression of the node, for instance its value
       or path.

   Set line comment
       Set the comment on the key node for more reliability (see below).

       Given a sample.yml file of:

	      a: cat

       then

	      yq '.a line_comment="single"' sample.yml

       will output

	      a: cat # single

   Set line comment of a maps/arrays
       For maps and arrays, you need to set the line comment on the key node.
       This will also work for scalars.

       Given a sample.yml file of:

	      a:
		b: things

       then

	      yq '(.a | key) line_comment="single"' sample.yml

       will output

	      a: # single
		b: things

   Use update assign to perform relative updates
       Given a sample.yml file of:

	      a: cat
	      b: dog

       then

	      yq '.. line_comment |= .' sample.yml

       will output

	      a: cat # cat
	      b: dog # dog

   Where is the comment - map key example
       The underlying yaml parser can assign comments in a document to
       surprising nodes.  Use an expression like this to find where you
       comment is.  `p' indicates the path, `isKey' is if the node is a map
       key (as opposed to a map value).  From this, you can see the
       `hello-world-comment' is actually on the `hello' key

       Given a sample.yml file of:

	      hello: # hello-world-comment
		message: world

       then

	      yq '[... | {"p": path | join("."), "isKey": is_key, "hc": headComment, "lc": lineComment, "fc": footComment}]' sample.yml

       will output

	      - p: ""
		isKey: false
		hc: ""
		lc: ""
		fc: ""
	      - p: hello
		isKey: true
		hc: ""
		lc: hello-world-comment
		fc: ""
	      - p: hello
		isKey: false
		hc: ""
		lc: ""
		fc: ""
	      - p: hello.message
		isKey: true
		hc: ""
		lc: ""
		fc: ""
	      - p: hello.message
		isKey: false
		hc: ""
		lc: ""
		fc: ""

   Retrieve comment - map key example
       From the previous example, we know that the comment is on the `hello'
       key as a lineComment

       Given a sample.yml file of:

	      hello: # hello-world-comment
		message: world

       then

	      yq '.hello | key | line_comment' sample.yml

       will output

	      hello-world-comment

   Where is the comment - array example
       The underlying yaml parser can assign comments in a document to
       surprising nodes.  Use an expression like this to find where you
       comment is.  `p' indicates the path, `isKey' is if the node is a map
       key (as opposed to a map value).  From this, you can see the
       `under-name-comment' is actually on the first child

       Given a sample.yml file of:

	      name:
		# under-name-comment
		- first-array-child

       then

	      yq '[... | {"p": path | join("."), "isKey": is_key, "hc": headComment, "lc": lineComment, "fc": footComment}]' sample.yml

       will output

	      - p: ""
		isKey: false
		hc: ""
		lc: ""
		fc: ""
	      - p: name
		isKey: true
		hc: ""
		lc: ""
		fc: ""
	      - p: name
		isKey: false
		hc: ""
		lc: ""
		fc: ""
	      - p: name.0
		isKey: false
		hc: under-name-comment
		lc: ""
		fc: ""

   Retrieve comment - array example
       From the previous example, we know that the comment is on the first
       child as a headComment

       Given a sample.yml file of:

	      name:
		# under-name-comment
		- first-array-child

       then

	      yq '.name[0] | headComment' sample.yml

       will output

	      under-name-comment

   Set head comment
       Given a sample.yml file of:

	      a: cat

       then

	      yq '. head_comment="single"' sample.yml

       will output

	      # single
	      a: cat

   Set head comment of a map entry
       Given a sample.yml file of:

	      f: foo
	      a:
		b: cat

       then

	      yq '(.a | key) head_comment="single"' sample.yml

       will output

	      f: foo
	      # single
	      a:
		b: cat

   Set foot comment, using an expression
       Given a sample.yml file of:

	      a: cat

       then

	      yq '. foot_comment=.a' sample.yml

       will output

	      a: cat
	      # cat

   Remove comment
       Given a sample.yml file of:

	      a: cat # comment
	      b: dog # leave this

       then

	      yq '.a line_comment=""' sample.yml

       will output

	      a: cat
	      b: dog # leave this

   Remove (strip) all comments
       Note the use of ... to ensure key nodes are included.

       Given a sample.yml file of:

	      # hi

	      a: cat # comment
	      # great
	      b: # key comment

       then

	      yq '... comments=""' sample.yml

       will output

	      a: cat
	      b:

   Get line comment
       Given a sample.yml file of:

	      # welcome!

	      a: cat # meow
	      # have a great day

       then

	      yq '.a | line_comment' sample.yml

       will output

	      meow

   Get head comment
       Given a sample.yml file of:

	      # welcome!

	      a: cat # meow

	      # have a great day

       then

	      yq '. | head_comment' sample.yml

       will output

	      welcome!

   Head comment with document split
       Given a sample.yml file of:

	      # welcome!
	      ---
	      # bob
	      a: cat # meow

	      # have a great day

       then

	      yq 'head_comment' sample.yml

       will output

	      welcome!
	      bob

   Get foot comment
       Given a sample.yml file of:

	      # welcome!

	      a: cat # meow

	      # have a great day
	      # no really

       then

	      yq '. | foot_comment' sample.yml

       will output

	      have a great day
	      no really

Compare Operators
       Comparison operators (>, >=, <, <=) can be used for comparing scalar
       values of the same time.

       The following types are currently supported:

       • numbers

       • strings

       • datetimes

   Related Operators
       • equals / not equals (==, !=) operators here
	 <https://mikefarah.gitbook.io/yq/operators/equals>

       • boolean operators (and, or, any etc) here
	 <https://mikefarah.gitbook.io/yq/operators/boolean-operators>

       • select operator here
	 <https://mikefarah.gitbook.io/yq/operators/select>

   Compare numbers (>)
       Given a sample.yml file of:

	      a: 5
	      b: 4

       then

	      yq '.a > .b' sample.yml

       will output

	      true

   Compare equal numbers (>=)
       Given a sample.yml file of:

	      a: 5
	      b: 5

       then

	      yq '.a >= .b' sample.yml

       will output

	      true

   Compare strings
       Compares strings by their bytecode.

       Given a sample.yml file of:

	      a: zoo
	      b: apple

       then

	      yq '.a > .b' sample.yml

       will output

	      true

   Compare date times
       You can compare date times.  Assumes RFC3339 date time format, see
       date-time operators
       <https://mikefarah.gitbook.io/yq/operators/date-time-operators> for
       more information.

       Given a sample.yml file of:

	      a: 2021-01-01T03:10:00Z
	      b: 2020-01-01T03:10:00Z

       then

	      yq '.a > .b' sample.yml

       will output

	      true

   Both sides are null: > is false
       Running

	      yq --null-input '.a > .b'

       will output

	      false

   Both sides are null: >= is true
       Running

	      yq --null-input '.a >= .b'

       will output

	      true

Contains
       This returns true if the context contains the passed in parameter, and
       false otherwise.  For arrays, this will return true if the passed in
       array is contained within the array.  For strings, it will return true
       if the string is a substring.

       {% hint style=“warning” %}

       Note that, just like jq, when checking if an array of strings contains
       another, this will use contains and not equals to check each string.
       This means an expression like contains(["cat"]) will return true for an
       array ["cats"].

       See the “Array has a subset array” example below on how to check for a
       subset.

       {% endhint %}

   Array contains array
       Array is equal or subset of

       Given a sample.yml file of:

	      - foobar
	      - foobaz
	      - blarp

       then

	      yq 'contains(["baz", "bar"])' sample.yml

       will output

	      true

   Array has a subset array
       Subtract the superset array from the subset, if there’s anything left,
       it’s not a subset

       Given a sample.yml file of:

	      - foobar
	      - foobaz
	      - blarp

       then

	      yq '["baz", "bar"] - . | length == 0' sample.yml

       will output

	      false

   Object included in array
       Given a sample.yml file of:

	      "foo": 12
	      "bar":
		- 1
		- 2
		- "barp": 12
		  "blip": 13

       then

	      yq 'contains({"bar": [{"barp": 12}]})' sample.yml

       will output

	      true

   Object not included in array
       Given a sample.yml file of:

	      "foo": 12
	      "bar":
		- 1
		- 2
		- "barp": 12
		  "blip": 13

       then

	      yq 'contains({"foo": 12, "bar": [{"barp": 15}]})' sample.yml

       will output

	      false

   String contains substring
       Given a sample.yml file of:

	      foobar

       then

	      yq 'contains("bar")' sample.yml

       will output

	      true

   String equals string
       Given a sample.yml file of:

	      meow

       then

	      yq 'contains("meow")' sample.yml

       will output

	      true

Create, Collect into Object
       This is used to construct objects (or maps).  This can be used against
       existing yaml, or to create fresh yaml documents.

   Collect empty object
       Running

	      yq --null-input '{}'

       will output

	      {}

   Wrap (prefix) existing object
       Given a sample.yml file of:

	      name: Mike

       then

	      yq '{"wrap": .}' sample.yml

       will output

	      wrap:
		name: Mike

   Using splat to create multiple objects
       Given a sample.yml file of:

	      name: Mike
	      pets:
		- cat
		- dog

       then

	      yq '{.name: .pets.[]}' sample.yml

       will output

	      Mike: cat
	      Mike: dog

   Working with multiple documents
       Given a sample.yml file of:

	      name: Mike
	      pets:
		- cat
		- dog
	      ---
	      name: Rosey
	      pets:
		- monkey
		- sheep

       then

	      yq '{.name: .pets.[]}' sample.yml

       will output

	      Mike: cat
	      Mike: dog
	      ---
	      Rosey: monkey
	      Rosey: sheep

   Creating yaml from scratch
       Running

	      yq --null-input '{"wrap": "frog"}'

       will output

	      wrap: frog

   Creating yaml from scratch with multiple objects
       Running

	      yq --null-input '(.a.b = "foo") | (.d.e = "bar")'

       will output

	      a:
		b: foo
	      d:
		e: bar

Date Time
       Various operators for parsing and manipulating dates.

   Date time formattings
       This uses Golang’s built in time library for parsing and formatting
       date times.

       When not specified, the RFC3339 standard is assumed
       2006-01-02T15:04:05Z07:00 for parsing.

       To specify a custom parsing format, use the with_dtf operator.  The
       first parameter sets the datetime parsing format for the expression in
       the second parameter.  The expression can be any valid yq expression
       tree.

	      yq 'with_dtf("myformat"; .a + "3h" | tz("Australia/Melbourne"))'

       See the library docs <https://pkg.go.dev/time#pkg-constants> for
       examples of formatting options.

   Timezones
       This uses Golang’s built in LoadLocation function to parse timezones
       strings.  See the library docs
       <https://pkg.go.dev/time#LoadLocation> for more details.

   Durations
       Durations are parsed using Golang’s built in ParseDuration
       <https://pkg.go.dev/time#ParseDuration> function.

       You can add durations to time using the + operator.

   Format: from standard RFC3339 format
       Providing a single parameter assumes a standard RFC3339 datetime
       format.	If the target format is not a valid yaml datetime format, the
       result will be a string tagged node.

       Given a sample.yml file of:

	      a: 2001-12-15T02:59:43.1Z

       then

	      yq '.a |= format_datetime("Monday, 02-Jan-06 at 3:04PM")' sample.yml

       will output

	      a: Saturday, 15-Dec-01 at 2:59AM

   Format: from custom date time
       Use with_dtf to set a custom datetime format for parsing.

       Given a sample.yml file of:

	      a: Saturday, 15-Dec-01 at 2:59AM

       then

	      yq '.a |= with_dtf("Monday, 02-Jan-06 at 3:04PM"; format_datetime("2006-01-02"))' sample.yml

       will output

	      a: 2001-12-15

   Format: get the day of the week
       Given a sample.yml file of:

	      a: 2001-12-15

       then

	      yq '.a | format_datetime("Monday")' sample.yml

       will output

	      Saturday

   Now
       Given a sample.yml file of:

	      a: cool

       then

	      yq '.updated = now' sample.yml

       will output

	      a: cool
	      updated: 2021-05-19T01:02:03Z

   From Unix
       Converts from unix time.  Note, you don’t have to pipe through the tz
       operator :)

       Running

	      yq --null-input '1675301929 | from_unix | tz("UTC")'

       will output

	      2023-02-02T01:38:49Z

   To Unix
       Converts to unix time

       Running

	      yq --null-input 'now | to_unix'

       will output

	      1621386123

   Timezone: from standard RFC3339 format
       Returns a new datetime in the specified timezone.  Specify standard
       IANA Time Zone format or `utc', `local'.  When given a single
       parameter, this assumes the datetime is in RFC3339 format.

       Given a sample.yml file of:

	      a: cool

       then

	      yq '.updated = (now | tz("Australia/Sydney"))' sample.yml

       will output

	      a: cool
	      updated: 2021-05-19T11:02:03+10:00

   Timezone: with custom format
       Specify standard IANA Time Zone format or `utc', `local'

       Given a sample.yml file of:

	      a: Saturday, 15-Dec-01 at 2:59AM GMT

       then

	      yq '.a |= with_dtf("Monday, 02-Jan-06 at 3:04PM MST"; tz("Australia/Sydney"))' sample.yml

       will output

	      a: Saturday, 15-Dec-01 at 1:59PM AEDT

   Add and tz custom format
       Specify standard IANA Time Zone format or `utc', `local'

       Given a sample.yml file of:

	      a: Saturday, 15-Dec-01 at 2:59AM GMT

       then

	      yq '.a |= with_dtf("Monday, 02-Jan-06 at 3:04PM MST"; tz("Australia/Sydney"))' sample.yml

       will output

	      a: Saturday, 15-Dec-01 at 1:59PM AEDT

   Date addition
       Given a sample.yml file of:

	      a: 2021-01-01T00:00:00Z

       then

	      yq '.a += "3h10m"' sample.yml

       will output

	      a: 2021-01-01T03:10:00Z

   Date subtraction
       You can subtract durations from dates.  Assumes RFC3339 date time
       format, see date-time operators
       <https://mikefarah.gitbook.io/yq/operators/datetime#date-time-formattings> for
       more information.

       Given a sample.yml file of:

	      a: 2021-01-01T03:10:00Z

       then

	      yq '.a -= "3h10m"' sample.yml

       will output

	      a: 2021-01-01T00:00:00Z

   Date addition - custom format
       Given a sample.yml file of:

	      a: Saturday, 15-Dec-01 at 2:59AM GMT

       then

	      yq 'with_dtf("Monday, 02-Jan-06 at 3:04PM MST"; .a += "3h1m")' sample.yml

       will output

	      a: Saturday, 15-Dec-01 at 6:00AM GMT

   Date script with custom format
       You can embed full expressions in with_dtf if needed.

       Given a sample.yml file of:

	      a: Saturday, 15-Dec-01 at 2:59AM GMT

       then

	      yq 'with_dtf("Monday, 02-Jan-06 at 3:04PM MST"; .a = (.a + "3h1m" | tz("Australia/Perth")))' sample.yml

       will output

	      a: Saturday, 15-Dec-01 at 2:00PM AWST

Delete
       Deletes matching entries in maps or arrays.

   Delete entry in map
       Given a sample.yml file of:

	      a: cat
	      b: dog

       then

	      yq 'del(.b)' sample.yml

       will output

	      a: cat

   Delete nested entry in map
       Given a sample.yml file of:

	      a:
		a1: fred
		a2: frood

       then

	      yq 'del(.a.a1)' sample.yml

       will output

	      a:
		a2: frood

   Delete entry in array
       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3

       then

	      yq 'del(.[1])' sample.yml

       will output

	      - 1
	      - 3

   Delete nested entry in array
       Given a sample.yml file of:

	      - a: cat
		b: dog

       then

	      yq 'del(.[0].a)' sample.yml

       will output

	      - b: dog

   Delete no matches
       Given a sample.yml file of:

	      a: cat
	      b: dog

       then

	      yq 'del(.c)' sample.yml

       will output

	      a: cat
	      b: dog

   Delete matching entries
       Given a sample.yml file of:

	      a: cat
	      b: dog
	      c: bat

       then

	      yq 'del( .[] | select(. == "*at") )' sample.yml

       will output

	      b: dog

   Recursively delete matching keys
       Given a sample.yml file of:

	      a:
		name: frog
		b:
		  name: blog
		  age: 12

       then

	      yq 'del(.. | select(has("name")).name)' sample.yml

       will output

	      a:
		b:
		  age: 12

Divide
       Divide behaves differently according to the type of the LHS: * strings:
       split by the divider * number: arithmetic division

   String split
       Given a sample.yml file of:

	      a: cat_meow
	      b: _

       then

	      yq '.c = .a / .b' sample.yml

       will output

	      a: cat_meow
	      b: _
	      c:
		- cat
		- meow

   Number division
       The result during division is calculated as a float

       Given a sample.yml file of:

	      a: 12
	      b: 2.5

       then

	      yq '.a = .a / .b' sample.yml

       will output

	      a: 4.8
	      b: 2.5

   Number division by zero
       Dividing by zero results in +Inf or -Inf

       Given a sample.yml file of:

	      a: 1
	      b: -1

       then

	      yq '.a = .a / 0 | .b = .b / 0' sample.yml

       will output

	      a: !!float +Inf
	      b: !!float -Inf

Document Index
       Use the documentIndex operator (or the di shorthand) to select nodes of
       a particular document.

   Retrieve a document index
       Given a sample.yml file of:

	      a: cat
	      ---
	      a: frog

       then

	      yq '.a | document_index' sample.yml

       will output

	      0
	      ---
	      1

   Retrieve a document index, shorthand
       Given a sample.yml file of:

	      a: cat
	      ---
	      a: frog

       then

	      yq '.a | di' sample.yml

       will output

	      0
	      ---
	      1

   Filter by document index
       Given a sample.yml file of:

	      a: cat
	      ---
	      a: frog

       then

	      yq 'select(document_index == 1)' sample.yml

       will output

	      a: frog

   Filter by document index shorthand
       Given a sample.yml file of:

	      a: cat
	      ---
	      a: frog

       then

	      yq 'select(di == 1)' sample.yml

       will output

	      a: frog

   Print Document Index with matches
       Given a sample.yml file of:

	      a: cat
	      ---
	      a: frog

       then

	      yq '.a | ({"match": ., "doc": document_index})' sample.yml

       will output

	      match: cat
	      doc: 0
	      ---
	      match: frog
	      doc: 1

Encoder / Decoder
       Encode operators will take the piped in object structure and encode it
       as a string in the desired format.  The decode operators do the
       opposite, they take a formatted string and decode it into the relevant
       object structure.

       Note that you can optionally pass an indent value to the encode
       functions (see below).

       These operators are useful to process yaml documents that have
       stringified embedded yaml/json/props in them.

       Format	    Decode (from	 Encode (to string)
		    string)
       ─────────────────────────────────────────────────────
       Yaml	    from_yaml/@yamld	 to_yaml(i)/@yaml
       JSON	    from_json/@jsond	 to_json(i)/@json
       Properties   from_props/@propsd	 to_props/@props
       CSV	    from_csv/@csvd	 to_csv/@csv
       TSV	    from_tsv/@tsvd	 to_tsv/@tsv
       XML	    from_xml/@xmld	 to_xml(i)/@xml
       Base64	    @base64d		 @base64
       URI	    @urid		 @uri
       Shell				 @sh

       See CSV and TSV documentation
       <https://mikefarah.gitbook.io/yq/usage/csv-tsv> for accepted formats.

       XML uses the --xml-attribute-prefix and xml-content-name flags to
       identify attributes and content fields.

       Base64 assumes rfc4648
       <https://rfc-editor.org/rfc/rfc4648.html> encoding.  Encoding and
       decoding both assume that the content is a utf-8 string and not binary
       content.

   Encode value as json string
       Given a sample.yml file of:

	      a:
		cool: thing

       then

	      yq '.b = (.a | to_json)' sample.yml

       will output

	      a:
		cool: thing
	      b: |
		{
		  "cool": "thing"
		}

   Encode value as json string, on one line
       Pass in a 0 indent to print json on a single line.

       Given a sample.yml file of:

	      a:
		cool: thing

       then

	      yq '.b = (.a | to_json(0))' sample.yml

       will output

	      a:
		cool: thing
	      b: '{"cool":"thing"}'

   Encode value as json string, on one line shorthand
       Pass in a 0 indent to print json on a single line.

       Given a sample.yml file of:

	      a:
		cool: thing

       then

	      yq '.b = (.a | @json)' sample.yml

       will output

	      a:
		cool: thing
	      b: '{"cool":"thing"}'

   Decode a json encoded string
       Keep in mind JSON is a subset of YAML.  If you want idiomatic yaml,
       pipe through the style operator to clear out the JSON styling.

       Given a sample.yml file of:

	      a: '{"cool":"thing"}'

       then

	      yq '.a | from_json | ... style=""' sample.yml

       will output

	      cool: thing

   Encode value as props string
       Given a sample.yml file of:

	      a:
		cool: thing

       then

	      yq '.b = (.a | @props)' sample.yml

       will output

	      a:
		cool: thing
	      b: |
		cool = thing

   Decode props encoded string
       Given a sample.yml file of:

	      a: |-
		cats=great
		dogs=cool as well

       then

	      yq '.a |= @propsd' sample.yml

       will output

	      a:
		cats: great
		dogs: cool as well

   Decode csv encoded string
       Given a sample.yml file of:

	      a: |-
		cats,dogs
		great,cool as well

       then

	      yq '.a |= @csvd' sample.yml

       will output

	      a:
		- cats: great
		  dogs: cool as well

   Decode tsv encoded string
       Given a sample.yml file of:

	      a: |-
		cats  dogs
		great cool as well

       then

	      yq '.a |= @tsvd' sample.yml

       will output

	      a:
		- cats: great
		  dogs: cool as well

   Encode value as yaml string
       Indent defaults to 2

       Given a sample.yml file of:

	      a:
		cool:
		  bob: dylan

       then

	      yq '.b = (.a | to_yaml)' sample.yml

       will output

	      a:
		cool:
		  bob: dylan
	      b: |
		cool:
		  bob: dylan

   Encode value as yaml string, with custom indentation
       You can specify the indentation level as the first parameter.

       Given a sample.yml file of:

	      a:
		cool:
		  bob: dylan

       then

	      yq '.b = (.a | to_yaml(8))' sample.yml

       will output

	      a:
		cool:
		  bob: dylan
	      b: |
		cool:
			bob: dylan

   Decode a yaml encoded string
       Given a sample.yml file of:

	      a: 'foo: bar'

       then

	      yq '.b = (.a | from_yaml)' sample.yml

       will output

	      a: 'foo: bar'
	      b:
		foo: bar

   Update a multiline encoded yaml string
       Given a sample.yml file of:

	      a: |
		foo: bar
		baz: dog

       then

	      yq '.a |= (from_yaml | .foo = "cat" | to_yaml)' sample.yml

       will output

	      a: |
		foo: cat
		baz: dog

   Update a single line encoded yaml string
       Given a sample.yml file of:

	      a: 'foo: bar'

       then

	      yq '.a |= (from_yaml | .foo = "cat" | to_yaml)' sample.yml

       will output

	      a: 'foo: cat'

   Encode array of scalars as csv string
       Scalars are strings, numbers and booleans.

       Given a sample.yml file of:

	      - cat
	      - thing1,thing2
	      - true
	      - 3.40

       then

	      yq '@csv' sample.yml

       will output

	      cat,"thing1,thing2",true,3.40

   Encode array of arrays as csv string
       Given a sample.yml file of:

	      - - cat
		- thing1,thing2
		- true
		- 3.40
	      - - dog
		- thing3
		- false
		- 12

       then

	      yq '@csv' sample.yml

       will output

	      cat,"thing1,thing2",true,3.40
	      dog,thing3,false,12

   Encode array of arrays as tsv string
       Scalars are strings, numbers and booleans.

       Given a sample.yml file of:

	      - - cat
		- thing1,thing2
		- true
		- 3.40
	      - - dog
		- thing3
		- false
		- 12

       then

	      yq '@tsv' sample.yml

       will output

	      cat thing1,thing2   true	  3.40
	      dog thing3  false   12

   Encode value as xml string
       Given a sample.yml file of:

	      a:
		cool:
		  foo: bar
		  +@id: hi

       then

	      yq '.a | to_xml' sample.yml

       will output

	      <cool id="hi">
		<foo>bar</foo>
	      </cool>

   Encode value as xml string on a single line
       Given a sample.yml file of:

	      a:
		cool:
		  foo: bar
		  +@id: hi

       then

	      yq '.a | @xml' sample.yml

       will output

	      <cool id="hi"><foo>bar</foo></cool>

   Encode value as xml string with custom indentation
       Given a sample.yml file of:

	      a:
		cool:
		  foo: bar
		  +@id: hi

       then

	      yq '{"cat": .a | to_xml(1)}' sample.yml

       will output

	      cat: |
		<cool id="hi">
		 <foo>bar</foo>
		</cool>

   Decode a xml encoded string
       Given a sample.yml file of:

	      a: <foo>bar</foo>

       then

	      yq '.b = (.a | from_xml)' sample.yml

       will output

	      a: <foo>bar</foo>
	      b:
		foo: bar

   Encode a string to base64
       Given a sample.yml file of:

	      coolData: a special string

       then

	      yq '.coolData | @base64' sample.yml

       will output

	      YSBzcGVjaWFsIHN0cmluZw==

   Encode a yaml document to base64
       Pipe through @yaml first to convert to a string, then use @base64 to
       encode it.

       Given a sample.yml file of:

	      a: apple

       then

	      yq '@yaml | @base64' sample.yml

       will output

	      YTogYXBwbGUK

   Encode a string to uri
       Given a sample.yml file of:

	      coolData: this has & special () characters *

       then

	      yq '.coolData | @uri' sample.yml

       will output

	      this+has+%26+special+%28%29+characters+%2A

   Decode a URI to a string
       Given a sample.yml file of:

	      this+has+%26+special+%28%29+characters+%2A

       then

	      yq '@urid' sample.yml

       will output

	      this has & special () characters *

   Encode a string to sh
       Sh/Bash friendly string

       Given a sample.yml file of:

	      coolData: strings with spaces and a 'quote'

       then

	      yq '.coolData | @sh' sample.yml

       will output

	      strings' with spaces and a '\'quote\'

   Decode a base64 encoded string
       Decoded data is assumed to be a string.

       Given a sample.yml file of:

	      coolData: V29ya3Mgd2l0aCBVVEYtMTYg8J+Yig==

       then

	      yq '.coolData | @base64d' sample.yml

       will output

	      Works with UTF-16 😊

   Decode a base64 encoded yaml document
       Pipe through from_yaml to parse the decoded base64 string as a yaml
       document.

       Given a sample.yml file of:

	      coolData: YTogYXBwbGUK

       then

	      yq '.coolData |= (@base64d | from_yaml)' sample.yml

       will output

	      coolData:
		a: apple

Entries
       Similar to the same named functions in jq these functions convert
       to/from an object and an array of key-value pairs.  This is most useful
       for performing operations on keys of maps.

       Use with_entries(op) as a syntactic sugar for doing to_entries | op |
       from_entries.

   to_entries Map
       Given a sample.yml file of:

	      a: 1
	      b: 2

       then

	      yq 'to_entries' sample.yml

       will output

	      - key: a
		value: 1
	      - key: b
		value: 2

   to_entries Array
       Given a sample.yml file of:

	      - a
	      - b

       then

	      yq 'to_entries' sample.yml

       will output

	      - key: 0
		value: a
	      - key: 1
		value: b

   to_entries null
       Given a sample.yml file of:

	      null

       then

	      yq 'to_entries' sample.yml

       will output


   from_entries map
       Given a sample.yml file of:

	      a: 1
	      b: 2

       then

	      yq 'to_entries | from_entries' sample.yml

       will output

	      a: 1
	      b: 2

   from_entries with numeric key indices
       from_entries always creates a map, even for numeric keys

       Given a sample.yml file of:

	      - a
	      - b

       then

	      yq 'to_entries | from_entries' sample.yml

       will output

	      0: a
	      1: b

   Use with_entries to update keys
       Given a sample.yml file of:

	      a: 1
	      b: 2

       then

	      yq 'with_entries(.key |= "KEY_" + .)' sample.yml

       will output

	      KEY_a: 1
	      KEY_b: 2

   Use with_entries to update keys recursively
       We use (..  | select(tag=“map”)) to find all the maps in the doc, then
       |= to update each one of those maps.  In the update, with_entries is
       used.

       Given a sample.yml file of:

	      a: 1
	      b:
		b_a: nested
		b_b: thing

       then

	      yq '(.. | select(tag=="!!map")) |= with_entries(.key |= "KEY_" + .)' sample.yml

       will output

	      KEY_a: 1
	      KEY_b:
		KEY_b_a: nested
		KEY_b_b: thing

   Custom sort map keys
       Use to_entries to convert to an array of key/value pairs, sort the
       array using sort/sort_by/etc, and convert it back.

       Given a sample.yml file of:

	      a: 1
	      c: 3
	      b: 2

       then

	      yq 'to_entries | sort_by(.key) | reverse | from_entries' sample.yml

       will output

	      c: 3
	      b: 2
	      a: 1

   Use with_entries to filter the map
       Given a sample.yml file of:

	      a:
		b: bird
	      c:
		d: dog

       then

	      yq 'with_entries(select(.value | has("b")))' sample.yml

       will output

	      a:
		b: bird

Env Variable Operators
       These operators are used to handle environment variables usage in
       expressions and documents.  While environment variables can, of course,
       be passed in via your CLI with string interpolation, this often comes
       with complex quote escaping and can be tricky to write and read.

       There are three operators:

       • env which takes a single environment variable name and parse the
	 variable as a yaml node (be it a map, array, string, number of
	 boolean)

       • strenv which also takes a single environment variable name, and
	 always parses the variable as a string.

       • envsubst which you pipe strings into and it interpolates environment
	 variables in strings using envsubst
	 <https://github.com/a8m/envsubst>.

   EnvSubst Options
       You can optionally pass envsubst any of the following options:

       • nu: NoUnset, this will fail if there are any referenced variables
	 that are not set

       • ne: NoEmpty, this will fail if there are any referenced variables
	 that are empty

       • ff: FailFast, this will abort on the first failure (rather than
	 collect all the errors)

       E.g: envsubst(ne, ff) will fail on the first empty variable.

       See Imposing Restrictions
       <https://github.com/a8m/envsubst#imposing-restrictions> in the envsubst
       documentation for more information, and below for examples.

   Tip
       To replace environment variables across all values in a document,
       envsubst can be used with the recursive descent operator as follows:

	      yq '(.. | select(tag == "!!str")) |= envsubst' file.yaml

   Disabling env operators
       If required, you can use the --security-disable-env-ops to disable env
       operations.

   Read string environment variable
       Running

	      myenv="cat meow" yq --null-input '.a = env(myenv)'

       will output

	      a: cat meow

   Read boolean environment variable
       Running

	      myenv="true" yq --null-input '.a = env(myenv)'

       will output

	      a: true

   Read numeric environment variable
       Running

	      myenv="12" yq --null-input '.a = env(myenv)'

       will output

	      a: 12

   Read yaml environment variable
       Running

	      myenv="{b: fish}" yq --null-input '.a = env(myenv)'

       will output

	      a: {b: fish}

   Read boolean environment variable as a string
       Running

	      myenv="true" yq --null-input '.a = strenv(myenv)'

       will output

	      a: "true"

   Read numeric environment variable as a string
       Running

	      myenv="12" yq --null-input '.a = strenv(myenv)'

       will output

	      a: "12"

   Dynamically update a path from an environment variable
       The env variable can be any valid yq expression.

       Given a sample.yml file of:

	      a:
		b:
		  - name: dog
		  - name: cat

       then

	      pathEnv=".a.b[0].name"  valueEnv="moo" yq 'eval(strenv(pathEnv)) = strenv(valueEnv)' sample.yml

       will output

	      a:
		b:
		  - name: moo
		  - name: cat

   Dynamic key lookup with environment variable
       Given a sample.yml file of:

	      cat: meow
	      dog: woof

       then

	      myenv="cat" yq '.[env(myenv)]' sample.yml

       will output

	      meow

   Replace strings with envsubst
       Running

	      myenv="cat" yq --null-input '"the ${myenv} meows" | envsubst'

       will output

	      the cat meows

   Replace strings with envsubst, missing variables
       Running

	      yq --null-input '"the ${myenvnonexisting} meows" | envsubst'

       will output

	      the  meows

   Replace strings with envsubst(nu), missing variables
       (nu) not unset, will fail if there are unset (missing) variables

       Running

	      yq --null-input '"the ${myenvnonexisting} meows" | envsubst(nu)'

       will output

	      Error: variable ${myenvnonexisting} not set

   Replace strings with envsubst(ne), missing variables
       (ne) not empty, only validates set variables

       Running

	      yq --null-input '"the ${myenvnonexisting} meows" | envsubst(ne)'

       will output

	      the  meows

   Replace strings with envsubst(ne), empty variable
       (ne) not empty, will fail if a references variable is empty

       Running

	      myenv="" yq --null-input '"the ${myenv} meows" | envsubst(ne)'

       will output

	      Error: variable ${myenv} set but empty

   Replace strings with envsubst, missing variables with defaults
       Running

	      yq --null-input '"the ${myenvnonexisting-dog} meows" | envsubst'

       will output

	      the dog meows

   Replace strings with envsubst(nu), missing variables with defaults
       Having a default specified skips over the missing variable.

       Running

	      yq --null-input '"the ${myenvnonexisting-dog} meows" | envsubst(nu)'

       will output

	      the dog meows

   Replace strings with envsubst(ne), missing variables with defaults
       Fails, because the variable is explicitly set to blank.

       Running

	      myEmptyEnv="" yq --null-input '"the ${myEmptyEnv-dog} meows" | envsubst(ne)'

       will output

	      Error: variable ${myEmptyEnv} set but empty

   Replace string environment variable in document
       Given a sample.yml file of:

	      v: ${myenv}

       then

	      myenv="cat meow" yq '.v |= envsubst' sample.yml

       will output

	      v: cat meow

   (Default) Return all envsubst errors
       By default, all errors are returned at once.

       Running

	      yq --null-input '"the ${notThere} ${alsoNotThere}" | envsubst(nu)'

       will output

	      Error: variable ${notThere} not set
	      variable ${alsoNotThere} not set

   Fail fast, return the first envsubst error (and abort)
       Running

	      yq --null-input '"the ${notThere} ${alsoNotThere}" | envsubst(nu,ff)'

       will output

	      Error: variable ${notThere} not set

   env() operation fails when security is enabled
       Use --security-disable-env-ops to disable env operations for security.

       Running

	      yq --null-input 'env("MYENV")'

       will output

	      Error: env operations have been disabled

   strenv() operation fails when security is enabled
       Use --security-disable-env-ops to disable env operations for security.

       Running

	      yq --null-input 'strenv("MYENV")'

       will output

	      Error: env operations have been disabled

   envsubst() operation fails when security is enabled
       Use --security-disable-env-ops to disable env operations for security.

       Running

	      yq --null-input '"value: ${MYENV}" | envsubst'

       will output

	      Error: env operations have been disabled

Equals / Not Equals
       This is a boolean operator that will return true if the LHS is equal to
       the RHS and false otherwise.

	      .a == .b

       It is most often used with the select operator to find particular
       nodes:

	      select(.a == .b)

       The not equals != operator returns false if the LHS is equal to the
       RHS.

   Related Operators
       • comparison (>=, < etc) operators here
	 <https://mikefarah.gitbook.io/yq/operators/compare>

       • boolean operators (and, or, any etc) here
	 <https://mikefarah.gitbook.io/yq/operators/boolean-operators>

       • select operator here
	 <https://mikefarah.gitbook.io/yq/operators/select>

   Match string
       Given a sample.yml file of:

	      - cat
	      - goat
	      - dog

       then

	      yq '.[] | (. == "*at")' sample.yml

       will output

	      true
	      true
	      false

   Don’t match string
       Given a sample.yml file of:

	      - cat
	      - goat
	      - dog

       then

	      yq '.[] | (. != "*at")' sample.yml

       will output

	      false
	      false
	      true

   Match number
       Given a sample.yml file of:

	      - 3
	      - 4
	      - 5

       then

	      yq '.[] | (. == 4)' sample.yml

       will output

	      false
	      true
	      false

   Don’t match number
       Given a sample.yml file of:

	      - 3
	      - 4
	      - 5

       then

	      yq '.[] | (. != 4)' sample.yml

       will output

	      true
	      false
	      true

   Match nulls
       Running

	      yq --null-input 'null == ~'

       will output

	      true

   Non existent key doesn’t equal a value
       Given a sample.yml file of:

	      a: frog

       then

	      yq 'select(.b != "thing")' sample.yml

       will output

	      a: frog

   Two non existent keys are equal
       Given a sample.yml file of:

	      a: frog

       then

	      yq 'select(.b == .c)' sample.yml

       will output

	      a: frog

Error
       Use this operation to short-circuit expressions.  Useful for
       validation.

   Validate a particular value
       Given a sample.yml file of:

	      a: hello

       then

	      yq 'select(.a == "howdy") or error(".a [" + .a + "] is not howdy!")' sample.yml

       will output

	      Error: .a [hello] is not howdy!

   Validate the environment variable is a number - invalid
       Running

	      numberOfCats="please" yq --null-input 'env(numberOfCats) | select(tag == "!!int") or error("numberOfCats is not a number :(")'

       will output

	      Error: numberOfCats is not a number :(

   Validate the environment variable is a number - valid
       with can be a convenient way of encapsulating validation.

       Given a sample.yml file of:

	      name: Bob
	      favouriteAnimal: cat

       then

	      numberOfCats="3" yq '
		  with(env(numberOfCats); select(tag == "!!int") or error("numberOfCats is not a number :(")) |
		  .numPets = env(numberOfCats)
	      ' sample.yml

       will output

	      name: Bob
	      favouriteAnimal: cat
	      numPets: 3

Eval
       Use eval to dynamically process an expression - for instance from an
       environment variable.

       eval takes a single argument, and evaluates that as a yq expression.
       Any valid expression can be used, be it a path .a.b.c | select(. ==
       "cat"), or an update .a.b.c = "gogo".

       Tip: This can be a useful way to parameterise complex scripts.

   Dynamically evaluate a path
       Given a sample.yml file of:

	      pathExp: .a.b[] | select(.name == "cat")
	      a:
		b:
		  - name: dog
		  - name: cat

       then

	      yq 'eval(.pathExp)' sample.yml

       will output

	      name: cat

   Dynamically update a path from an environment variable
       The env variable can be any valid yq expression.

       Given a sample.yml file of:

	      a:
		b:
		  - name: dog
		  - name: cat

       then

	      pathEnv=".a.b[0].name"  valueEnv="moo" yq 'eval(strenv(pathEnv)) = strenv(valueEnv)' sample.yml

       will output

	      a:
		b:
		  - name: moo
		  - name: cat

File Operators
       File operators are most often used with merge when needing to merge
       specific files together.  Note that when doing this, you will need to
       use eval-all to ensure all yaml documents are loaded into memory before
       performing the merge (as opposed to eval which runs the expression once
       per document).

       Note that the fileIndex operator has a short alias of fi.

   Merging files
       Note the use of eval-all to ensure all documents are loaded into
       memory.

	      yq eval-all 'select(fi == 0) * select(filename == "file2.yaml")' file1.yaml file2.yaml

   Get filename
       Given a sample.yml file of:

	      a: cat

       then

	      yq 'filename' sample.yml

       will output

	      sample.yml

   Get file index
       Given a sample.yml file of:

	      a: cat

       then

	      yq 'file_index' sample.yml

       will output

	      0

   Get file indices of multiple documents
       Given a sample.yml file of:

	      a: cat

       And another sample another.yml file of:

	      a: cat

       then

	      yq eval-all 'file_index' sample.yml another.yml

       will output

	      0
	      1

   Get file index alias
       Given a sample.yml file of:

	      a: cat

       then

	      yq 'fi' sample.yml

       will output

	      0

Filter
       Filters an array (or map values) by the expression given.  Equivalent
       to doing map(select(exp)).

   Filter array
       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3

       then

	      yq 'filter(. < 3)' sample.yml

       will output

	      - 1
	      - 2

   Filter map values
       Given a sample.yml file of:

	      c:
		things: cool
		frog: yes
	      d:
		things: hot
		frog: false

       then

	      yq 'filter(.things == "cool")' sample.yml

       will output

	      - things: cool
		frog: yes

First
       Returns the first matching element in an array, or first matching value
       in a map.

       Can be given an expression to match with, otherwise will just return
       the first.

   First matching element from array
       Given a sample.yml file of:

	      - a: banana
	      - a: cat
	      - a: apple

       then

	      yq 'first(.a == "cat")' sample.yml

       will output

	      a: cat

   First matching element from array with multiple matches
       Given a sample.yml file of:

	      - a: banana
	      - a: cat
		b: firstCat
	      - a: apple
	      - a: cat
		b: secondCat

       then

	      yq 'first(.a == "cat")' sample.yml

       will output

	      a: cat
	      b: firstCat

   First matching element from array with numeric condition
       Given a sample.yml file of:

	      - a: 10
	      - a: 100
	      - a: 1
	      - a: 101

       then

	      yq 'first(.a > 50)' sample.yml

       will output

	      a: 100

   First matching element from array with boolean condition
       Given a sample.yml file of:

	      - a: false
	      - a: true
		b: firstTrue
	      - a: false
	      - a: true
		b: secondTrue

       then

	      yq 'first(.a == true)' sample.yml

       will output

	      a: true
	      b: firstTrue

   First matching element from array with null values
       Given a sample.yml file of:

	      - a: null
	      - a: cat
	      - a: apple

       then

	      yq 'first(.a != null)' sample.yml

       will output

	      a: cat

   First matching element from array with complex condition
       Given a sample.yml file of:

	      - a: dog
		b: 7
	      - a: cat
		b: 3
	      - a: apple
		b: 5

       then

	      yq 'first(.b > 4 and .b < 6)' sample.yml

       will output

	      a: apple
	      b: 5

   First matching element from map
       Given a sample.yml file of:

	      x:
		a: banana
	      y:
		a: cat
	      z:
		a: apple

       then

	      yq 'first(.a == "cat")' sample.yml

       will output

	      a: cat

   First matching element from map with numeric condition
       Given a sample.yml file of:

	      x:
		a: 10
	      y:
		a: 100
	      z:
		a: 101

       then

	      yq 'first(.a > 50)' sample.yml

       will output

	      a: 100

   First matching element from nested structure
       Given a sample.yml file of:

	      items:
		- a: banana
		- a: cat
		- a: apple

       then

	      yq '.items | first(.a == "cat")' sample.yml

       will output

	      a: cat

   First matching element with no matches
       Given a sample.yml file of:

	      - a: banana
	      - a: cat
	      - a: apple

       then

	      yq 'first(.a == "dog")' sample.yml

       will output


   First matching element from empty array
       Given a sample.yml file of:

	      []

       then

	      yq 'first(.a == "cat")' sample.yml

       will output


   First matching element from scalar node
       Given a sample.yml file of:

	      hello

       then

	      yq 'first(. == "hello")' sample.yml

       will output


   First matching element from null node
       Given a sample.yml file of:

	      null

       then

	      yq 'first(. == "hello")' sample.yml

       will output


   First matching element with string condition
       Given a sample.yml file of:

	      - a: banana
	      - a: cat
	      - a: apple

       then

	      yq 'first(.a | test("^c"))' sample.yml

       will output

	      a: cat

   First matching element with length condition
       Given a sample.yml file of:

	      - a: hi
	      - a: hello
	      - a: world

       then

	      yq 'first(.a | length > 4)' sample.yml

       will output

	      a: hello

   First matching element from array of strings
       Given a sample.yml file of:

	      - banana
	      - cat
	      - apple

       then

	      yq 'first(. == "cat")' sample.yml

       will output

	      cat

   First matching element from array of numbers
       Given a sample.yml file of:

	      - 10
	      - 100
	      - 1

       then

	      yq 'first(. > 50)' sample.yml

       will output

	      100

   First element with no filter from array
       Given a sample.yml file of:

	      - 10
	      - 100
	      - 1

       then

	      yq 'first' sample.yml

       will output

	      10

   First element with no filter from array of maps
       Given a sample.yml file of:

	      - a: 10
	      - a: 100

       then

	      yq 'first' sample.yml

       will output

	      a: 10

Flatten
       This recursively flattens arrays.

   Flatten
       Recursively flattens all arrays

       Given a sample.yml file of:

	      - 1
	      - - 2
	      - - - 3

       then

	      yq 'flatten' sample.yml

       will output

	      - 1
	      - 2
	      - 3

   Flatten with depth of one
       Given a sample.yml file of:

	      - 1
	      - - 2
	      - - - 3

       then

	      yq 'flatten(1)' sample.yml

       will output

	      - 1
	      - 2
	      - - 3

   Flatten empty array
       Given a sample.yml file of:

	      - []

       then

	      yq 'flatten' sample.yml

       will output

	      []

   Flatten array of objects
       Given a sample.yml file of:

	      - foo: bar
	      - - foo: baz

       then

	      yq 'flatten' sample.yml

       will output

	      - foo: bar
	      - foo: baz

Group By
       This is used to group items in an array by an expression.

   Group by field
       Given a sample.yml file of:

	      - foo: 1
		bar: 10
	      - foo: 3
		bar: 100
	      - foo: 1
		bar: 1

       then

	      yq 'group_by(.foo)' sample.yml

       will output

	      - - foo: 1
		  bar: 10
		- foo: 1
		  bar: 1
	      - - foo: 3
		  bar: 100

   Group by field, with nulls
       Given a sample.yml file of:

	      - cat: dog
	      - foo: 1
		bar: 10
	      - foo: 3
		bar: 100
	      - no: foo for you
	      - foo: 1
		bar: 1

       then

	      yq 'group_by(.foo)' sample.yml

       will output

	      - - cat: dog
		- no: foo for you
	      - - foo: 1
		  bar: 10
		- foo: 1
		  bar: 1
	      - - foo: 3
		  bar: 100

Has
       This operation returns true if the key exists in a map (or index in an
       array), false otherwise.

   Has map key
       Given a sample.yml file of:

	      - a: yes
	      - a: ~
	      - a:
	      - b: nope

       then

	      yq '.[] | has("a")' sample.yml

       will output

	      true
	      true
	      true
	      false

   Select, checking for existence of deep paths
       Simply pipe in parent expressions into has

       Given a sample.yml file of:

	      - a:
		  b:
		    c: cat
	      - a:
		  b:
		    d: dog

       then

	      yq '.[] | select(.a.b | has("c"))' sample.yml

       will output

	      a:
		b:
		  c: cat

   Has array index
       Given a sample.yml file of:

	      - []
	      - [1]
	      - [1, 2]
	      - [1, null]
	      - [1, 2, 3]

       then

	      yq '.[] | has(1)' sample.yml

       will output

	      false
	      false
	      true
	      true
	      true

Keys
       Use the keys operator to return map keys or array indices.

   Map keys
       Given a sample.yml file of:

	      dog: woof
	      cat: meow

       then

	      yq 'keys' sample.yml

       will output

	      - dog
	      - cat

   Array keys
       Given a sample.yml file of:

	      - apple
	      - banana

       then

	      yq 'keys' sample.yml

       will output

	      - 0
	      - 1

   Retrieve array key
       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3

       then

	      yq '.[1] | key' sample.yml

       will output

	      1

   Retrieve map key
       Given a sample.yml file of:

	      a: thing

       then

	      yq '.a | key' sample.yml

       will output

	      a

   No key
       Given a sample.yml file of:

	      {}

       then

	      yq 'key' sample.yml

       will output


   Update map key
       Given a sample.yml file of:

	      a:
		x: 3
		y: 4

       then

	      yq '(.a.x | key) = "meow"' sample.yml

       will output

	      a:
		meow: 3
		y: 4

   Get comment from map key
       Given a sample.yml file of:

	      a:
		# comment on key
		x: 3
		y: 4

       then

	      yq '.a.x | key | headComment' sample.yml

       will output

	      comment on key

   Check node is a key
       Given a sample.yml file of:

	      a:
		b:
		  - cat
		c: frog

       then

	      yq '[... | { "p": path | join("."), "isKey": is_key, "tag": tag }]' sample.yml

       will output

	      - p: ""
		isKey: false
		tag: '!!map'
	      - p: a
		isKey: true
		tag: '!!str'
	      - p: a
		isKey: false
		tag: '!!map'
	      - p: a.b
		isKey: true
		tag: '!!str'
	      - p: a.b
		isKey: false
		tag: '!!seq'
	      - p: a.b.0
		isKey: false
		tag: '!!str'
	      - p: a.c
		isKey: true
		tag: '!!str'
	      - p: a.c
		isKey: false
		tag: '!!str'

Kind
       The kind operator identifies the type of a node as either scalar, map,
       or seq.

       This can be used for filtering or transforming nodes based on their
       type.

       Note that null values are treated as scalar.

   Get kind
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f: []
	      g: {}
	      h: null

       then

	      yq '.. | kind' sample.yml

       will output

	      map
	      scalar
	      scalar
	      scalar
	      scalar
	      seq
	      map
	      scalar

   Get kind, ignores custom tags
       Unlike tag, kind is not affected by custom tags.

       Given a sample.yml file of:

	      a: !!thing cat
	      b: !!foo {}
	      c: !!bar []

       then

	      yq '.. | kind' sample.yml

       will output

	      map
	      scalar
	      map
	      seq

   Add comments only to scalars
       An example of how you can use kind

       Given a sample.yml file of:

	      a:
		b: 5
		c: 3.2
	      e: true
	      f: []
	      g: {}
	      h: null

       then

	      yq '(.. | select(kind == "scalar")) line_comment = "this is a scalar"' sample.yml

       will output

	      a:
		b: 5 # this is a scalar
		c: 3.2 # this is a scalar
	      e: true # this is a scalar
	      f: []
	      g: {}
	      h: null # this is a scalar

Length
       Returns the lengths of the nodes.  Length is defined according to the
       type of the node.

   String length
       returns length of string

       Given a sample.yml file of:

	      a: cat

       then

	      yq '.a | length' sample.yml

       will output

	      3

   null length
       Given a sample.yml file of:

	      a: null

       then

	      yq '.a | length' sample.yml

       will output

	      0

   Map length
       returns number of entries

       Given a sample.yml file of:

	      a: cat
	      c: dog

       then

	      yq 'length' sample.yml

       will output

	      2

   Array length
       returns number of elements

       Given a sample.yml file of:

	      - 2
	      - 4
	      - 6
	      - 8

       then

	      yq 'length' sample.yml

       will output

	      4

Line
       Returns the line of the matching node.  Starts from 1, 0 indicates
       there was no line data.

   Returns line of value node
       Given a sample.yml file of:

	      a: cat
	      b:
		c: cat

       then

	      yq '.b | line' sample.yml

       will output

	      3

   Returns line of key node
       Pipe through the key operator to get the line of the key

       Given a sample.yml file of:

	      a: cat
	      b:
		c: cat

       then

	      yq '.b | key | line' sample.yml

       will output

	      2

   First line is 1
       Given a sample.yml file of:

	      a: cat

       then

	      yq '.a | line' sample.yml

       will output

	      1

   No line data is 0
       Running

	      yq --null-input '{"a": "new entry"} | line'

       will output

	      0

Load
       The load operators allows you to load in content from another file.

       Note that you can use string operators like + and sub to modify the
       value in the yaml file to a path that exists in your system.

       You can load files of the following supported types:

       Format	      Load Operator
       ─────────────────────────────
       Yaml	      load
       XML	      load_xml
       Properties     load_props
       Plain String   load_str
       Base64	      load_base64

       Note that load_base64 only works for base64 encoded utf-8 strings.

   Samples files for tests:
   yaml
       ../../examples/thing.yml:

	      a: apple is included
	      b: cool

   xml
       small.xml:

	      <this>is some xml</this>

   properties
       small.properties:

	      this.is = a properties file

   base64
       base64.txt:

	      bXkgc2VjcmV0IGNoaWxsaSByZWNpcGUgaXMuLi4u

   Disabling file operators
       If required, you can use the --security-disable-file-ops to disable
       file operations.

   Simple example
       Given a sample.yml file of:

	      myFile: ../../examples/thing.yml

       then

	      yq 'load(.myFile)' sample.yml

       will output

	      a: apple is included
	      b: cool.

   Replace node with referenced file
       Note that you can modify the filename in the load operator if needed.

       Given a sample.yml file of:

	      something:
		file: thing.yml

       then

	      yq '.something |= load("../../examples/" + .file)' sample.yml

       will output

	      something:
		a: apple is included
		b: cool.

   Replace all nodes with referenced file
       Recursively match all the nodes (..) and then filter the ones that have
       a `file' attribute.

       Given a sample.yml file of:

	      something:
		file: thing.yml
	      over:
		here:
		  - file: thing.yml

       then

	      yq '(.. | select(has("file"))) |= load("../../examples/" + .file)' sample.yml

       will output

	      something:
		a: apple is included
		b: cool.
	      over:
		here:
		  - a: apple is included
		    b: cool.

   Replace node with referenced file as string
       This will work for any text based file

       Given a sample.yml file of:

	      something:
		file: thing.yml

       then

	      yq '.something |= load_str("../../examples/" + .file)' sample.yml

       will output

	      something: |-
		a: apple is included
		b: cool.

   Load from XML
       Given a sample.yml file of:

	      cool: things

       then

	      yq '.more_stuff = load_xml("../../examples/small.xml")' sample.yml

       will output

	      cool: things
	      more_stuff:
		this: is some xml

   Load from Properties
       Given a sample.yml file of:

	      cool: things

       then

	      yq '.more_stuff = load_props("../../examples/small.properties")' sample.yml

       will output

	      cool: things
	      more_stuff:
		this:
		  is: a properties file

   Merge from properties
       This can be used as a convenient way to update a yaml document

       Given a sample.yml file of:

	      this:
		is: from yaml
		cool: ay

       then

	      yq '. *= load_props("../../examples/small.properties")' sample.yml

       will output

	      this:
		is: a properties file
		cool: ay

   Load from base64 encoded file
       Given a sample.yml file of:

	      cool: things

       then

	      yq '.more_stuff = load_base64("../../examples/base64.txt")' sample.yml

       will output

	      cool: things
	      more_stuff: my secret chilli recipe is....

   load() operation fails when security is enabled
       Use --security-disable-file-ops to disable file operations for
       security.

       Running

	      yq --null-input 'load("../../examples/thing.yml")'

       will output

	      Error: file operations have been disabled

   load_str() operation fails when security is enabled
       Use --security-disable-file-ops to disable file operations for
       security.

       Running

	      yq --null-input 'load_str("../../examples/thing.yml")'

       will output

	      Error: file operations have been disabled

   load_xml() operation fails when security is enabled
       Use --security-disable-file-ops to disable file operations for
       security.

       Running

	      yq --null-input 'load_xml("../../examples/small.xml")'

       will output

	      Error: file operations have been disabled

   load_props() operation fails when security is enabled
       Use --security-disable-file-ops to disable file operations for
       security.

       Running

	      yq --null-input 'load_props("../../examples/small.properties")'

       will output

	      Error: file operations have been disabled

   load_base64() operation fails when security is enabled
       Use --security-disable-file-ops to disable file operations for
       security.

       Running

	      yq --null-input 'load_base64("../../examples/base64.txt")'

       will output

	      Error: file operations have been disabled

Map
       Maps values of an array.  Use map_values to map values of an object.

   Map array
       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3

       then

	      yq 'map(. + 1)' sample.yml

       will output

	      - 2
	      - 3
	      - 4

   Map object values
       Given a sample.yml file of:

	      a: 1
	      b: 2
	      c: 3

       then

	      yq 'map_values(. + 1)' sample.yml

       will output

	      a: 2
	      b: 3
	      c: 4

Max
       Computes the maximum among an incoming sequence of scalar values.

   Maximum int
       Given a sample.yml file of:

	      - 99
	      - 16
	      - 12
	      - 6
	      - 66

       then

	      yq 'max' sample.yml

       will output

	      99

   Maximum string
       Given a sample.yml file of:

	      - foo
	      - bar
	      - baz

       then

	      yq 'max' sample.yml

       will output

	      foo

   Maximum of empty
       Given a sample.yml file of:

	      []

       then

	      yq 'max' sample.yml

       will output


Min
       Computes the minimum among an incoming sequence of scalar values.

   Minimum int
       Given a sample.yml file of:

	      - 99
	      - 16
	      - 12
	      - 6
	      - 66

       then

	      yq 'min' sample.yml

       will output

	      6

   Minimum string
       Given a sample.yml file of:

	      - foo
	      - bar
	      - baz

       then

	      yq 'min' sample.yml

       will output

	      bar

   Minimum of empty
       Given a sample.yml file of:

	      []

       then

	      yq 'min' sample.yml

       will output


Modulo
       Arithmetic modulo operator, returns the remainder from dividing two
       numbers.

   Number modulo - int
       If the lhs and rhs are ints then the expression will be calculated with
       ints.

       Given a sample.yml file of:

	      a: 13
	      b: 2

       then

	      yq '.a = .a % .b' sample.yml

       will output

	      a: 1
	      b: 2

   Number modulo - float
       If the lhs or rhs are floats then the expression will be calculated
       with floats.

       Given a sample.yml file of:

	      a: 12
	      b: 2.5

       then

	      yq '.a = .a % .b' sample.yml

       will output

	      a: !!float 2
	      b: 2.5

   Number modulo - int by zero
       If the lhs is an int and rhs is a 0 the result is an error.

       Given a sample.yml file of:

	      a: 1
	      b: 0

       then

	      yq '.a = .a % .b' sample.yml

       will output

	      Error: cannot modulo by 0

   Number modulo - float by zero
       If the lhs is a float and rhs is a 0 the result is NaN.

       Given a sample.yml file of:

	      a: 1.1
	      b: 0

       then

	      yq '.a = .a % .b' sample.yml

       will output

	      a: !!float NaN
	      b: 0

Multiply (Merge)
       Like the multiple operator in jq, depending on the operands, this
       multiply operator will do different things.  Currently numbers, arrays
       and objects are supported.

   Objects and arrays - merging
       Objects are merged deeply matching on matching keys.  By default, array
       values override and are not deeply merged.

       You can use the add operator +, to shallow merge objects, see more info
       here <https://mikefarah.gitbook.io/yq/operators/add>.

       Note that when merging objects, this operator returns the merged object
       (not the parent).  This will be clearer in the examples below.

   Merge Flags
       You can control how objects are merged by using one or more of the
       following flags.  Multiple flags can be used together, e.g. .a *+? .b.
       See examples below

       • + append arrays

       • d deeply merge arrays

       • ? only merge existing fields

       • n only merge new fields

       • c clobber custom tags

       To perform a shallow merge only, use the add operator +, see more info
       here <https://mikefarah.gitbook.io/yq/operators/add>.

   Merge two files together
       This uses the load operator to merge file2 into file1.

	      yq '. *= load("file2.yml")' file1.yml

   Merging all files
       Note the use of eval-all to ensure all documents are loaded into
       memory.

	      yq eval-all '. as $item ireduce ({}; . * $item )' *.yml

Merging complex arrays together by a key field
       By default - yq merge is naive.	It merges maps when they match the key
       name, and arrays are merged either by appending them together, or
       merging the entries by their position in the array.

       For more complex array merging (e.g. merging items that match on a
       certain key) please see the example here
       <https://mikefarah.gitbook.io/yq/operators/multiply-merge#merge-arrays-of-objects-together-matching-on-a-key>

   Multiply integers
       Given a sample.yml file of:

	      a: 3
	      b: 4

       then

	      yq '.a *= .b' sample.yml

       will output

	      a: 12
	      b: 4

   Multiply string node X int
       Given a sample.yml file of:

	      b: banana

       then

	      yq '.b * 4' sample.yml

       will output

	      bananabananabananabanana

   Multiply int X string node
       Given a sample.yml file of:

	      b: banana

       then

	      yq '4 * .b' sample.yml

       will output

	      bananabananabananabanana

   Multiply string X int node
       Given a sample.yml file of:

	      n: 4

       then

	      yq '"banana" * .n' sample.yml

       will output

	      bananabananabananabanana

   Multiply int node X string
       Given a sample.yml file of:

	      n: 4

       then

	      yq '.n * "banana"' sample.yml

       will output

	      bananabananabananabanana

   Merge objects together, returning merged result only
       Given a sample.yml file of:

	      a:
		field: me
		fieldA: cat
	      b:
		field:
		  g: wizz
		fieldB: dog

       then

	      yq '.a * .b' sample.yml

       will output

	      field:
		g: wizz
	      fieldA: cat
	      fieldB: dog

   Merge objects together, returning parent object
       Given a sample.yml file of:

	      a:
		field: me
		fieldA: cat
	      b:
		field:
		  g: wizz
		fieldB: dog

       then

	      yq '. * {"a":.b}' sample.yml

       will output

	      a:
		field:
		  g: wizz
		fieldA: cat
		fieldB: dog
	      b:
		field:
		  g: wizz
		fieldB: dog

   Merge keeps style of LHS
       Given a sample.yml file of:

	      a: {things: great}
	      b:
		also: "me"

       then

	      yq '. * {"a":.b}' sample.yml

       will output

	      a: {things: great, also: "me"}
	      b:
		also: "me"

   Merge arrays
       Given a sample.yml file of:

	      a:
		- 1
		- 2
		- 3
	      b:
		- 3
		- 4
		- 5

       then

	      yq '. * {"a":.b}' sample.yml

       will output

	      a:
		- 3
		- 4
		- 5
	      b:
		- 3
		- 4
		- 5

   Merge, only existing fields
       Given a sample.yml file of:

	      a:
		thing: one
		cat: frog
	      b:
		missing: two
		thing: two

       then

	      yq '.a *? .b' sample.yml

       will output

	      thing: two
	      cat: frog

   Merge, only new fields
       Given a sample.yml file of:

	      a:
		thing: one
		cat: frog
	      b:
		missing: two
		thing: two

       then

	      yq '.a *n .b' sample.yml

       will output

	      thing: one
	      cat: frog
	      missing: two

   Merge, appending arrays
       Given a sample.yml file of:

	      a:
		array:
		  - 1
		  - 2
		  - animal: dog
		value: coconut
	      b:
		array:
		  - 3
		  - 4
		  - animal: cat
		value: banana

       then

	      yq '.a *+ .b' sample.yml

       will output

	      array:
		- 1
		- 2
		- animal: dog
		- 3
		- 4
		- animal: cat
	      value: banana

   Merge, only existing fields, appending arrays
       Given a sample.yml file of:

	      a:
		thing:
		  - 1
		  - 2
	      b:
		thing:
		  - 3
		  - 4
		another:
		  - 1

       then

	      yq '.a *?+ .b' sample.yml

       will output

	      thing:
		- 1
		- 2
		- 3
		- 4

   Merge, deeply merging arrays
       Merging arrays deeply means arrays are merged like objects, with
       indices as their key.  In this case, we merge the first item in the
       array and do nothing with the second.

       Given a sample.yml file of:

	      a:
		- name: fred
		  age: 12
		- name: bob
		  age: 32
	      b:
		- name: fred
		  age: 34

       then

	      yq '.a *d .b' sample.yml

       will output

	      - name: fred
		age: 34
	      - name: bob
		age: 32

   Merge arrays of objects together, matching on a key
       This is a fairly complex expression - you can use it as is by providing
       the environment variables as seen in the example below.

       It merges in the array provided in the second file into the first -
       matching on equal keys.

       Explanation:

       The approach, at a high level, is to reduce into a merged map (keyed by
       the unique key) and then convert that back into an array.

       First the expression will create a map from the arrays keyed by the
       idPath, the unique field we want to merge by.  The reduce operator is
       merging `({}; .	* $item )', so array elements with the matching key
       will be merged together.

       Next, we convert the map back to an array, using reduce again,
       concatenating all the map values together.

       Finally, we set the result of the merged array back into the first doc.

       Thanks Kev from stackoverflow
       <https://stackoverflow.com/a/70109529/1168223>

       Given a sample.yml file of:

	      myArray:
		- a: apple
		  b: appleB
		- a: kiwi
		  b: kiwiB
		- a: banana
		  b: bananaB
	      something: else

       And another sample another.yml file of:

	      newArray:
		- a: banana
		  c: bananaC
		- a: apple
		  b: appleB2
		- a: dingo
		  c: dingoC

       then

	      idPath=".a"  originalPath=".myArray"  otherPath=".newArray" yq eval-all '
	      (
		(( (eval(strenv(originalPath)) + eval(strenv(otherPath)))  | .[] | {(eval(strenv(idPath))):  .}) as $item ireduce ({}; . * $item )) as $uniqueMap
		| ( $uniqueMap	| to_entries | .[]) as $item ireduce([]; . + $item.value)
	      ) as $mergedArray
	      | select(fi == 0) | (eval(strenv(originalPath))) = $mergedArray
	      ' sample.yml another.yml

       will output

	      myArray:
		- a: apple
		  b: appleB2
		- a: kiwi
		  b: kiwiB
		- a: banana
		  b: bananaB
		  c: bananaC
		- a: dingo
		  c: dingoC
	      something: else

   Merge to prefix an element
       Given a sample.yml file of:

	      a: cat
	      b: dog

       then

	      yq '. * {"a": {"c": .a}}' sample.yml

       will output

	      a:
		c: cat
	      b: dog

   Merge with simple aliases
       Given a sample.yml file of:

	      a: &cat
		c: frog
	      b:
		f: *cat
	      c:
		g: thongs

       then

	      yq '.c * .b' sample.yml

       will output

	      g: thongs
	      f: *cat

   Merge copies anchor names
       Given a sample.yml file of:

	      a:
		c: &cat frog
	      b:
		f: *cat
	      c:
		g: thongs

       then

	      yq '.c * .a' sample.yml

       will output

	      g: thongs
	      c: &cat frog

   Merge with merge anchors
       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobar * .foobarList' sample.yml

       will output

	      c: foobarList_c
	      !!merge <<:
		- *foo
		- *bar
	      thing: foobar_thing
	      b: foobarList_b

   Custom types: that are really numbers
       When custom tags are encountered, yq will try to decode the underlying
       type.

       Given a sample.yml file of:

	      a: !horse 2
	      b: !goat 3

       then

	      yq '.a = .a * .b' sample.yml

       will output

	      a: !horse 6
	      b: !goat 3

   Custom types: that are really maps
       Custom tags will be maintained.

       Given a sample.yml file of:

	      a: !horse
		cat: meow
	      b: !goat
		dog: woof

       then

	      yq '.a = .a * .b' sample.yml

       will output

	      a: !horse
		cat: meow
		dog: woof
	      b: !goat
		dog: woof

   Custom types: clobber tags
       Use the c option to clobber custom tags.  Note that the second tag is
       now used.

       Given a sample.yml file of:

	      a: !horse
		cat: meow
	      b: !goat
		dog: woof

       then

	      yq '.a *=c .b' sample.yml

       will output

	      a: !goat
		cat: meow
		dog: woof
	      b: !goat
		dog: woof

   Merging a null with a map
       Running

	      yq --null-input 'null * {"some": "thing"}'

       will output

	      some: thing

   Merging a map with null
       Running

	      yq --null-input '{"some": "thing"} * null'

       will output

	      some: thing

   Merging a null with an array
       Running

	      yq --null-input 'null * ["some"]'

       will output

	      - some

   Merging an array with null
       Running

	      yq --null-input '["some"] * null'

       will output

	      - some

Omit
       Works like pick, but instead you specify the keys/indices that you
       don’t want included.

   Omit keys from map
       Note that non existent keys are skipped.

       Given a sample.yml file of:

	      myMap:
		cat: meow
		dog: bark
		thing: hamster
		hamster: squeak

       then

	      yq '.myMap |= omit(["hamster", "cat", "goat"])' sample.yml

       will output

	      myMap:
		dog: bark
		thing: hamster

   Omit indices from array
       Note that non existent indices are skipped.

       Given a sample.yml file of:

	      - cat
	      - leopard
	      - lion

       then

	      yq 'omit([2, 0, 734, -5])' sample.yml

       will output

	      - leopard

Parent
       Parent simply returns the parent nodes of the matching nodes.

   Simple example
       Given a sample.yml file of:

	      a:
		nested: cat

       then

	      yq '.a.nested | parent' sample.yml

       will output

	      nested: cat

   Parent of nested matches
       Given a sample.yml file of:

	      a:
		fruit: apple
		name: bob
	      b:
		fruit: banana
		name: sam

       then

	      yq '.. | select(. == "banana") | parent' sample.yml

       will output

	      fruit: banana
	      name: sam

   Get parent attribute
       Given a sample.yml file of:

	      a:
		fruit: apple
		name: bob
	      b:
		fruit: banana
		name: sam

       then

	      yq '.. | select(. == "banana") | parent.name' sample.yml

       will output

	      sam

   Get parents
       Match all parents

       Given a sample.yml file of:

	      a:
		b:
		  c: cat

       then

	      yq '.a.b.c | parents' sample.yml

       will output

	      - c: cat
	      - b:
		  c: cat
	      - a:
		  b:
		    c: cat

   N-th parent
       You can optionally supply the number of levels to go up for the parent,
       the default being 1.

       Given a sample.yml file of:

	      a:
		b:
		  c: cat

       then

	      yq '.a.b.c | parent(2)' sample.yml

       will output

	      b:
		c: cat

   N-th parent - another level
       Given a sample.yml file of:

	      a:
		b:
		  c: cat

       then

	      yq '.a.b.c | parent(3)' sample.yml

       will output

	      a:
		b:
		  c: cat

   No parent
       Given a sample.yml file of:

	      {}

       then

	      yq 'parent' sample.yml

       will output


Path
       The path operator can be used to get the traversal paths of matching
       nodes in an expression.	The path is returned as an array, which if
       traversed in order will lead to the matching node.

       You can get the key/index of matching nodes by using the path operator
       to return the path array then piping that through .[-1] to get the last
       element of that array, the key.

       Use setpath to set a value to the path array returned by path, and
       similarly delpaths for an array of path arrays.

   Map path
       Given a sample.yml file of:

	      a:
		b: cat

       then

	      yq '.a.b | path' sample.yml

       will output

	      - a
	      - b

   Get map key
       Given a sample.yml file of:

	      a:
		b: cat

       then

	      yq '.a.b | path | .[-1]' sample.yml

       will output

	      b

   Array path
       Given a sample.yml file of:

	      a:
		- cat
		- dog

       then

	      yq '.a.[] | select(. == "dog") | path' sample.yml

       will output

	      - a
	      - 1

   Get array index
       Given a sample.yml file of:

	      a:
		- cat
		- dog

       then

	      yq '.a.[] | select(. == "dog") | path | .[-1]' sample.yml

       will output

	      1

   Print path and value
       Given a sample.yml file of:

	      a:
		- cat
		- dog
		- frog

       then

	      yq '.a[] | select(. == "*og") | [{"path":path, "value":.}]' sample.yml

       will output

	      - path:
		  - a
		  - 1
		value: dog
	      - path:
		  - a
		  - 2
		value: frog

   Set path
       Given a sample.yml file of:

	      a:
		b: cat

       then

	      yq 'setpath(["a", "b"]; "things")' sample.yml

       will output

	      a:
		b: things

   Set on empty document
       Running

	      yq --null-input 'setpath(["a", "b"]; "things")'

       will output

	      a:
		b: things

   Set path to prune deep paths
       Like pick but recursive.  This uses ireduce to deeply set the selected
       paths into an empty object.

       Given a sample.yml file of:


	      parentA: bob
	      parentB:
		child1: i am child1
		child2: i am child2
	      parentC:
		child1: me child1
		child2: me child2

       then

	      yq '(.parentB.child2, .parentC.child1) as $i
		ireduce({}; setpath($i | path; $i))' sample.yml

       will output

	      parentB:
		child2: i am child2
	      parentC:
		child1: me child1

   Set array path
       Given a sample.yml file of:

	      a:
		- cat
		- frog

       then

	      yq 'setpath(["a", 0]; "things")' sample.yml

       will output

	      a:
		- things
		- frog

   Set array path empty
       Running

	      yq --null-input 'setpath(["a", 0]; "things")'

       will output

	      a:
		- things

   Delete path
       Notice delpaths takes an array of paths.

       Given a sample.yml file of:

	      a:
		b: cat
		c: dog
		d: frog

       then

	      yq 'delpaths([["a", "c"], ["a", "d"]])' sample.yml

       will output

	      a:
		b: cat

   Delete array path
       Given a sample.yml file of:

	      a:
		- cat
		- frog

       then

	      yq 'delpaths([["a", 0]])' sample.yml

       will output

	      a:
		- frog

   Delete - wrong parameter
       delpaths does not work with a single path array

       Given a sample.yml file of:

	      a:
		- cat
		- frog

       then

	      yq 'delpaths(["a", 0])' sample.yml

       will output

	      Error: DELPATHS: expected entry [0] to be a sequence, but its a !!str. Note that delpaths takes an array of path arrays, e.g. [["a", "b"]]

Pick
       Filter a map by the specified list of keys.  Map is returned with the
       key in the order of the pick list.

       Similarly, filter an array by the specified list of indices.

   Pick keys from map
       Note that the order of the keys matches the pick order and non existent
       keys are skipped.

       Given a sample.yml file of:

	      myMap:
		cat: meow
		dog: bark
		thing: hamster
		hamster: squeak

       then

	      yq '.myMap |= pick(["hamster", "cat", "goat"])' sample.yml

       will output

	      myMap:
		hamster: squeak
		cat: meow

   Pick keys from map, included all the keys
       We create a map of the picked keys plus all the current keys, and run
       that through unique

       Given a sample.yml file of:

	      myMap:
		cat: meow
		dog: bark
		thing: hamster
		hamster: squeak

       then

	      yq '.myMap |= pick( (["thing"] + keys) | unique)' sample.yml

       will output

	      myMap:
		thing: hamster
		cat: meow
		dog: bark
		hamster: squeak

   Pick indices from array
       Note that the order of the indices matches the pick order and non
       existent indices are skipped.

       Given a sample.yml file of:

	      - cat
	      - leopard
	      - lion

       then

	      yq 'pick([2, 0, 734, -5])' sample.yml

       will output

	      - lion
	      - cat

Pipe
       Pipe the results of an expression into another.	Like the bash
       operator.

   Simple Pipe
       Given a sample.yml file of:

	      a:
		b: cat

       then

	      yq '.a | .b' sample.yml

       will output

	      cat

   Multiple updates
       Given a sample.yml file of:

	      a: cow
	      b: sheep
	      c: same

       then

	      yq '.a = "cat" | .b = "dog"' sample.yml

       will output

	      a: cat
	      b: dog
	      c: same

Pivot
       Emulates the PIVOT function supported by several popular RDBMS systems.

   Pivot a sequence of sequences
       Given a sample.yml file of:

	      - - foo
		- bar
		- baz
	      - - sis
		- boom
		- bah

       then

	      yq 'pivot' sample.yml

       will output

	      - - foo
		- sis
	      - - bar
		- boom
	      - - baz
		- bah

   Pivot sequence of heterogeneous sequences
       Missing values are “padded” to null.

       Given a sample.yml file of:

	      - - foo
		- bar
		- baz
	      - - sis
		- boom
		- bah
		- blah

       then

	      yq 'pivot' sample.yml

       will output

	      - - foo
		- sis
	      - - bar
		- boom
	      - - baz
		- bah
	      - -
		- blah

   Pivot sequence of maps
       Given a sample.yml file of:

	      - foo: a
		bar: b
		baz: c
	      - foo: x
		bar: y
		baz: z

       then

	      yq 'pivot' sample.yml

       will output

	      foo:
		- a
		- x
	      bar:
		- b
		- y
	      baz:
		- c
		- z

   Pivot sequence of heterogeneous maps
       Missing values are “padded” to null.

       Given a sample.yml file of:

	      - foo: a
		bar: b
		baz: c
	      - foo: x
		bar: y
		baz: z
		what: ever

       then

	      yq 'pivot' sample.yml

       will output

	      foo:
		- a
		- x
	      bar:
		- b
		- y
	      baz:
		- c
		- z
	      what:
		-
		- ever

Recursive Descent (Glob)
       This operator recursively matches (or globs) all children nodes given
       of a particular element, including that node itself.  This is most
       often used to apply a filter recursively against all matches.

   match values form ..
       This will, like the jq equivalent, recursively match all value nodes.
       Use it to find/manipulate particular values.

       For instance to set the style of all value nodes in a yaml doc,
       excluding map keys:

	      yq '.. style= "flow"' file.yaml

   match values and map keys form ...
       The also includes map keys in the results set.  This is particularly
       useful in YAML as unlike JSON, map keys can have their own styling and
       tags and also use anchors and aliases.

       For instance to set the style of all nodes in a yaml doc, including the
       map keys:

	      yq '... style= "flow"' file.yaml

   Recurse map (values only)
       Given a sample.yml file of:

	      a: frog

       then

	      yq '..' sample.yml

       will output

	      a: frog
	      frog

   Recursively find nodes with keys
       Note that this example has wrapped the expression in [] to show that
       there are two matches returned.	You do not have to wrap in [] in your
       path expression.

       Given a sample.yml file of:

	      a:
		name: frog
		b:
		  name: blog
		  age: 12

       then

	      yq '[.. | select(has("name"))]' sample.yml

       will output

	      - name: frog
		b:
		  name: blog
		  age: 12
	      - name: blog
		age: 12

   Recursively find nodes with values
       Given a sample.yml file of:

	      a:
		nameA: frog
		b:
		  nameB: frog
		  age: 12

       then

	      yq '.. | select(. == "frog")' sample.yml

       will output

	      frog
	      frog

   Recurse map (values and keys)
       Note that the map key appears in the results

       Given a sample.yml file of:

	      a: frog

       then

	      yq '...' sample.yml

       will output

	      a: frog
	      a
	      frog

   Aliases are not traversed
       Given a sample.yml file of:

	      a: &cat
		c: frog
	      b: *cat

       then

	      yq '[..]' sample.yml

       will output

	      - a: &cat
		  c: frog
		b: *cat
	      - &cat
		c: frog
	      - frog
	      - *cat

   Merge docs are not traversed
       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobar | [..]' sample.yml

       will output

	      - c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing
	      - foobar_c
	      - *foo
	      - foobar_thing

Reduce
       Reduce is a powerful way to process a collection of data into a new
       form.

	      <exp> as $<name> ireduce (<init>; <block>)

       e.g.

	      .[] as $item ireduce (0; . + $item)

       On the LHS we are configuring the collection of items that will be
       reduced <exp> as well as what each element will be called $<name>.
       Note that the array has been splatted into its individual elements.

       On the RHS there is <init>, the starting value of the accumulator and
       <block>, the expression that will update the accumulator for each
       element in the collection.  Note that within the block expression, .
       will evaluate to the current value of the accumulator.

   yq vs jq syntax
       Reduce syntax in yq is a little different from jq - as yq (currently)
       isn’t as sophisticated as jq and its only supports infix notation
       (e.g. a + b, where the operator is in the middle of the two parameters)
       - where as jq uses a mix of infix notation with prefix notation
       (e.g. reduce a b is like writing + a b).

       To that end, the reduce operator is called ireduce for backwards
       compatibility if a jq like prefix version of reduce is ever added.

   Sum numbers
       Given a sample.yml file of:

	      - 10
	      - 2
	      - 5
	      - 3

       then

	      yq '.[] as $item ireduce (0; . + $item)' sample.yml

       will output

	      20

   Merge all yaml files together
       Given a sample.yml file of:

	      a: cat

       And another sample another.yml file of:

	      b: dog

       then

	      yq eval-all '. as $item ireduce ({}; . * $item )' sample.yml another.yml

       will output

	      a: cat
	      b: dog

   Convert an array to an object
       Given a sample.yml file of:

	      - name: Cathy
		has: apples
	      - name: Bob
		has: bananas

       then

	      yq '.[] as $item ireduce ({}; .[$item | .name] = ($item | .has) )' sample.yml

       will output

	      Cathy: apples
	      Bob: bananas

Reverse
       Reverses the order of the items in an array

   Reverse
       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3

       then

	      yq 'reverse' sample.yml

       will output

	      - 3
	      - 2
	      - 1

   Sort descending by string field
       Use sort with reverse to sort in descending order.

       Given a sample.yml file of:

	      - a: banana
	      - a: cat
	      - a: apple

       then

	      yq 'sort_by(.a) | reverse' sample.yml

       will output

	      - a: cat
	      - a: banana
	      - a: apple

Select
       Select is used to filter arrays and maps by a boolean expression.

   Related Operators
       • equals / not equals (==, !=) operators here
	 <https://mikefarah.gitbook.io/yq/operators/equals>

       • comparison (>=, < etc) operators here
	 <https://mikefarah.gitbook.io/yq/operators/compare>

       • boolean operators (and, or, any etc) here
	 <https://mikefarah.gitbook.io/yq/operators/boolean-operators>

   Select elements from array using wildcard prefix
       Given a sample.yml file of:

	      - cat
	      - goat
	      - dog

       then

	      yq '.[] | select(. == "*at")' sample.yml

       will output

	      cat
	      goat

   Select elements from array using wildcard suffix
       Given a sample.yml file of:

	      - go-kart
	      - goat
	      - dog

       then

	      yq '.[] | select(. == "go*")' sample.yml

       will output

	      go-kart
	      goat

   Select elements from array using wildcard prefix and suffix
       Given a sample.yml file of:

	      - ago
	      - go
	      - meow
	      - going

       then

	      yq '.[] | select(. == "*go*")' sample.yml

       will output

	      ago
	      go
	      going

   Select elements from array with regular expression
       See more regular expression examples under the string operator docs
       <https://mikefarah.gitbook.io/yq/operators/string-operators>.

       Given a sample.yml file of:

	      - this_0
	      - not_this
	      - nor_0_this
	      - thisTo_4

       then

	      yq '.[] | select(test("[a-zA-Z]+_[0-9]$"))' sample.yml

       will output

	      this_0
	      thisTo_4

   Select items from a map
       Given a sample.yml file of:

	      things: cat
	      bob: goat
	      horse: dog

       then

	      yq '.[] | select(. == "cat" or test("og$"))' sample.yml

       will output

	      cat
	      dog

   Use select and with_entries to filter map keys
       Given a sample.yml file of:

	      name: bob
	      legs: 2
	      game: poker

       then

	      yq 'with_entries(select(.key | test("ame$")))' sample.yml

       will output

	      name: bob
	      game: poker

   Select multiple items in a map and update
       Note the brackets around the entire LHS.

       Given a sample.yml file of:

	      a:
		things: cat
		bob: goat
		horse: dog

       then

	      yq '(.a.[] | select(. == "cat" or . == "goat")) |= "rabbit"' sample.yml

       will output

	      a:
		things: rabbit
		bob: rabbit
		horse: dog

Shuffle
       Shuffles an array.  Note that this command does not use a
       cryptographically secure random number generator to randomise the array
       order.

   Shuffle array
       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3
	      - 4
	      - 5

       then

	      yq 'shuffle' sample.yml

       will output

	      - 5
	      - 2
	      - 4
	      - 1
	      - 3

   Shuffle array in place
       Given a sample.yml file of:

	      cool:
		- 1
		- 2
		- 3
		- 4
		- 5

       then

	      yq '.cool |= shuffle' sample.yml

       will output

	      cool:
		- 5
		- 2
		- 4
		- 1
		- 3

Slice/Splice Array
       The slice array operator takes an array as input and returns a
       subarray.  Like the jq equivalent, .[10:15] will return an array of
       length 5, starting from index 10 inclusive, up to index 15 exclusive.
       Negative numbers count backwards from the end of the array.

       You may leave out the first or second number, which will refer to the
       start or end of the array respectively.

   Slicing arrays
       Given a sample.yml file of:

	      - cat
	      - dog
	      - frog
	      - cow

       then

	      yq '.[1:3]' sample.yml

       will output

	      - dog
	      - frog

   Slicing arrays - without the first number
       Starts from the start of the array

       Given a sample.yml file of:

	      - cat
	      - dog
	      - frog
	      - cow

       then

	      yq '.[:2]' sample.yml

       will output

	      - cat
	      - dog

   Slicing arrays - without the second number
       Finishes at the end of the array

       Given a sample.yml file of:

	      - cat
	      - dog
	      - frog
	      - cow

       then

	      yq '.[2:]' sample.yml

       will output

	      - frog
	      - cow

   Slicing arrays - use negative numbers to count backwards from the end
       Given a sample.yml file of:

	      - cat
	      - dog
	      - frog
	      - cow

       then

	      yq '.[1:-1]' sample.yml

       will output

	      - dog
	      - frog

   Inserting into the middle of an array
       using an expression to find the index

       Given a sample.yml file of:

	      - cat
	      - dog
	      - frog
	      - cow

       then

	      yq '(.[] | select(. == "dog") | key + 1) as $pos | .[0:($pos)] + ["rabbit"] + .[$pos:]' sample.yml

       will output

	      - cat
	      - dog
	      - rabbit
	      - frog
	      - cow

Sort Keys
       The Sort Keys operator sorts maps by their keys (based on their string
       value).	This operator does not do anything to arrays or scalars (so
       you can easily recursively apply it to all maps).

       Sort is particularly useful for diffing two different yaml documents:

	      yq -i -P 'sort_keys(..)' file1.yml
	      yq -i -P 'sort_keys(..)' file2.yml
	      diff file1.yml file2.yml

       Note that yq does not yet consider anchors when sorting by keys - this
       may result in invalid yaml documents if you are using merge anchors.

       For more advanced sorting, you can use the sort_by
       <https://mikefarah.gitbook.io/yq/operators/sort> function on a map, and
       give it a custom function like sort_by(key | downcase).

   Sort keys of map
       Given a sample.yml file of:

	      c: frog
	      a: blah
	      b: bing

       then

	      yq 'sort_keys(.)' sample.yml

       will output

	      a: blah
	      b: bing
	      c: frog

   Sort keys recursively
       Note the array elements are left unsorted, but maps inside arrays are
       sorted

       Given a sample.yml file of:

	      bParent:
		c: dog
		array:
		  - 3
		  - 1
		  - 2
	      aParent:
		z: donkey
		x:
		  - c: yum
		    b: delish
		  - b: ew
		    a: apple

       then

	      yq 'sort_keys(..)' sample.yml

       will output

	      aParent:
		x:
		  - b: delish
		    c: yum
		  - a: apple
		    b: ew
		z: donkey
	      bParent:
		array:
		  - 3
		  - 1
		  - 2
		c: dog

Sort
       Sorts an array.	Use sort to sort an array as is, or sort_by(exp) to
       sort by a particular expression (e.g. subfield).

       To sort by descending order, pipe the results through the reverse
       operator after sorting.

       Note that at this stage, yq only sorts scalar fields.

   Sort by string field
       Given a sample.yml file of:

	      - a: banana
	      - a: cat
	      - a: apple

       then

	      yq 'sort_by(.a)' sample.yml

       will output

	      - a: apple
	      - a: banana
	      - a: cat

   Sort by multiple fields
       Given a sample.yml file of:

	      - a: dog
	      - a: cat
		b: banana
	      - a: cat
		b: apple

       then

	      yq 'sort_by(.a, .b)' sample.yml

       will output

	      - a: cat
		b: apple
	      - a: cat
		b: banana
	      - a: dog

   Sort descending by string field
       Use sort with reverse to sort in descending order.

       Given a sample.yml file of:

	      - a: banana
	      - a: cat
	      - a: apple

       then

	      yq 'sort_by(.a) | reverse' sample.yml

       will output

	      - a: cat
	      - a: banana
	      - a: apple

   Sort array in place
       Given a sample.yml file of:

	      cool:
		- a: banana
		- a: cat
		- a: apple

       then

	      yq '.cool |= sort_by(.a)' sample.yml

       will output

	      cool:
		- a: apple
		- a: banana
		- a: cat

   Sort array of objects by key
       Note that you can give sort_by complex expressions, not just paths

       Given a sample.yml file of:

	      cool:
		- b: banana
		- a: banana
		- c: banana

       then

	      yq '.cool |= sort_by(keys | .[0])' sample.yml

       will output

	      cool:
		- a: banana
		- b: banana
		- c: banana

   Sort a map
       Sorting a map, by default this will sort by the values

       Given a sample.yml file of:

	      y: b
	      z: a
	      x: c

       then

	      yq 'sort' sample.yml

       will output

	      z: a
	      y: b
	      x: c

   Sort a map by keys
       Use sort_by to sort a map using a custom function

       Given a sample.yml file of:

	      Y: b
	      z: a
	      x: c

       then

	      yq 'sort_by(key | downcase)' sample.yml

       will output

	      x: c
	      Y: b
	      z: a

   Sort is stable
       Note the order of the elements in unchanged when equal in sorting.

       Given a sample.yml file of:

	      - a: banana
		b: 1
	      - a: banana
		b: 2
	      - a: banana
		b: 3
	      - a: banana
		b: 4

       then

	      yq 'sort_by(.a)' sample.yml

       will output

	      - a: banana
		b: 1
	      - a: banana
		b: 2
	      - a: banana
		b: 3
	      - a: banana
		b: 4

   Sort by numeric field
       Given a sample.yml file of:

	      - a: 10
	      - a: 100
	      - a: 1

       then

	      yq 'sort_by(.a)' sample.yml

       will output

	      - a: 1
	      - a: 10
	      - a: 100

   Sort by custom date field
       Given a sample.yml file of:

	      - a: 12-Jun-2011
	      - a: 23-Dec-2010
	      - a: 10-Aug-2011

       then

	      yq 'with_dtf("02-Jan-2006"; sort_by(.a))' sample.yml

       will output

	      - a: 23-Dec-2010
	      - a: 12-Jun-2011
	      - a: 10-Aug-2011

   Sort, nulls come first
       Given a sample.yml file of:

	      - 8
	      - 3
	      - null
	      - 6
	      - true
	      - false
	      - cat

       then

	      yq 'sort' sample.yml

       will output

	      - null
	      - false
	      - true
	      - 3
	      - 6
	      - 8
	      - cat

Split into Documents
       This operator splits all matches into separate documents

   Split empty
       Running

	      yq --null-input 'split_doc'

       will output


   Split array
       Given a sample.yml file of:

	      - a: cat
	      - b: dog

       then

	      yq '.[] | split_doc' sample.yml

       will output

	      a: cat
	      ---
	      b: dog

String Operators
   RegEx
       This uses Golang’s native regex functions under the hood - See their
       docs <https://github.com/google/re2/wiki/Syntax> for the supported
       syntax.

       Case insensitive tip: prefix the regex with (?i) -
       e.g. test("(?i)cats").

   match(regEx)
       This operator returns the substring match details of the given regEx.

   capture(regEx)
       Capture returns named RegEx capture groups in a map.  Can be more
       convenient than match depending on what you are doing.

   test(regEx)
       Returns true if the string matches the RegEx, false otherwise.

   sub(regEx, replacement)
       Substitutes matched substrings.	The first parameter is the regEx to
       match substrings within the original string.  The second parameter
       specifies what to replace those matches with.  This can refer to
       capture groups from the first RegEx.

   String blocks, bash and newlines
       Bash is notorious for chomping on precious trailing newline characters,
       making it tricky to set strings with newlines properly.	In particular,
       the $( exp ) will trim trailing newlines.

       For instance to get this yaml:

	      a: |
		cat

       Using $( exp ) wont work, as it will trim the trailing newline.

	      m=$(echo "cat\n") yq -n '.a = strenv(m)'
	      a: cat

       However, using printf works:

	      printf -v m "cat\n" ; m="$m" yq -n '.a = strenv(m)'
	      a: |
		cat

       As well as having multiline expressions:

	      m="cat
	      "  yq -n '.a = strenv(m)'
	      a: |
		cat

       Similarly, if you’re trying to set the content from a file, and want a
       trailing newline:

	      IFS= read -rd '' output < <(cat my_file)
	      output=$output ./yq '.data.values = strenv(output)' first.yml

   Interpolation
       Given a sample.yml file of:

	      value: things
	      another: stuff

       then

	      yq '.message = "I like \(.value) and \(.another)"' sample.yml

       will output

	      value: things
	      another: stuff
	      message: I like things and stuff

   Interpolation - not a string
       Given a sample.yml file of:

	      value:
		an: apple

       then

	      yq '.message = "I like \(.value)"' sample.yml

       will output

	      value:
		an: apple
	      message: 'I like an: apple'

   To up (upper) case
       Works with unicode characters

       Given a sample.yml file of:

	      água

       then

	      yq 'upcase' sample.yml

       will output

	      ÁGUA

   To down (lower) case
       Works with unicode characters

       Given a sample.yml file of:

	      ÁgUA

       then

	      yq 'downcase' sample.yml

       will output

	      água

   Join strings
       Given a sample.yml file of:

	      - cat
	      - meow
	      - 1
	      - null
	      - true

       then

	      yq 'join("; ")' sample.yml

       will output

	      cat; meow; 1; ; true

   Trim strings
       Given a sample.yml file of:

	      - ' cat'
	      - 'dog '
	      - ' cow cow '
	      - horse

       then

	      yq '.[] | trim' sample.yml

       will output

	      cat
	      dog
	      cow cow
	      horse

   Match string
       Given a sample.yml file of:

	      foo bar foo

       then

	      yq 'match("foo")' sample.yml

       will output

	      string: foo
	      offset: 0
	      length: 3
	      captures: []

   Match string, case insensitive
       Given a sample.yml file of:

	      foo bar FOO

       then

	      yq '[match("(?i)foo"; "g")]' sample.yml

       will output

	      - string: foo
		offset: 0
		length: 3
		captures: []
	      - string: FOO
		offset: 8
		length: 3
		captures: []

   Match with global capture group
       Given a sample.yml file of:

	      abc abc

       then

	      yq '[match("(ab)(c)"; "g")]' sample.yml

       will output

	      - string: abc
		offset: 0
		length: 3
		captures:
		  - string: ab
		    offset: 0
		    length: 2
		  - string: c
		    offset: 2
		    length: 1
	      - string: abc
		offset: 4
		length: 3
		captures:
		  - string: ab
		    offset: 4
		    length: 2
		  - string: c
		    offset: 6
		    length: 1

   Match with named capture groups
       Given a sample.yml file of:

	      foo bar foo foo  foo

       then

	      yq '[match("foo (?P<bar123>bar)? foo"; "g")]' sample.yml

       will output

	      - string: foo bar foo
		offset: 0
		length: 11
		captures:
		  - string: bar
		    offset: 4
		    length: 3
		    name: bar123
	      - string: foo  foo
		offset: 12
		length: 8
		captures:
		  - string: null
		    offset: -1
		    length: 0
		    name: bar123

   Capture named groups into a map
       Given a sample.yml file of:

	      xyzzy-14

       then

	      yq 'capture("(?P<a>[a-z]+)-(?P<n>[0-9]+)")' sample.yml

       will output

	      a: xyzzy
	      n: "14"

   Match without global flag
       Given a sample.yml file of:

	      cat cat

       then

	      yq 'match("cat")' sample.yml

       will output

	      string: cat
	      offset: 0
	      length: 3
	      captures: []

   Match with global flag
       Given a sample.yml file of:

	      cat cat

       then

	      yq '[match("cat"; "g")]' sample.yml

       will output

	      - string: cat
		offset: 0
		length: 3
		captures: []
	      - string: cat
		offset: 4
		length: 3
		captures: []

   Test using regex
       Like jq’s equivalent, this works like match but only returns true/false
       instead of full match details

       Given a sample.yml file of:

	      - cat
	      - dog

       then

	      yq '.[] | test("at")' sample.yml

       will output

	      true
	      false

   Substitute / Replace string
       This uses Golang’s regex, described here
       <https://github.com/google/re2/wiki/Syntax>.  Note the use of |= to run
       in context of the current string value.

       Given a sample.yml file of:

	      a: dogs are great

       then

	      yq '.a |= sub("dogs", "cats")' sample.yml

       will output

	      a: cats are great

   Substitute / Replace string with regex
       This uses Golang’s regex, described here
       <https://github.com/google/re2/wiki/Syntax>.  Note the use of |= to run
       in context of the current string value.

       Given a sample.yml file of:

	      a: cat
	      b: heat

       then

	      yq '.[] |= sub("(a)", "${1}r")' sample.yml

       will output

	      a: cart
	      b: heart

   Custom types: that are really strings
       When custom tags are encountered, yq will try to decode the underlying
       type.

       Given a sample.yml file of:

	      a: !horse cat
	      b: !goat heat

       then

	      yq '.[] |= sub("(a)", "${1}r")' sample.yml

       will output

	      a: !horse cart
	      b: !goat heart

   Split strings
       Given a sample.yml file of:

	      cat; meow; 1; ; true

       then

	      yq 'split("; ")' sample.yml

       will output

	      - cat
	      - meow
	      - "1"
	      - ""
	      - "true"

   Split strings one match
       Given a sample.yml file of:

	      word

       then

	      yq 'split("; ")' sample.yml

       will output

	      - word

   To string
       Note that you may want to force yq to leave scalar values wrapped by
       passing in --unwrapScalar=false or -r=f

       Given a sample.yml file of:

	      - 1
	      - true
	      - null
	      - ~
	      - cat
	      - an: object
	      - - array
		- 2

       then

	      yq '.[] |= to_string' sample.yml

       will output

	      - "1"
	      - "true"
	      - "null"
	      - "~"
	      - cat
	      - "an: object"
	      - "- array\n- 2"

Style
       The style operator can be used to get or set the style of nodes
       (e.g. string style, yaml style).  Use this to control the formatting of
       the document in yaml.

   Update and set style of a particular node (simple)
       Given a sample.yml file of:

	      a:
		b: thing
		c: something

       then

	      yq '.a.b = "new" | .a.b style="double"' sample.yml

       will output

	      a:
		b: "new"
		c: something

   Update and set style of a particular node using path variables
       Given a sample.yml file of:

	      a:
		b: thing
		c: something

       then

	      yq 'with(.a.b ; . = "new" | . style="double")' sample.yml

       will output

	      a:
		b: "new"
		c: something

   Set tagged style
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f:
		- 1
		- 2
		- 3
	      g:
		something: cool

       then

	      yq '.. style="tagged"' sample.yml

       will output

	      !!map
	      a: !!str cat
	      b: !!int 5
	      c: !!float 3.2
	      e: !!bool true
	      f: !!seq
		- !!int 1
		- !!int 2
		- !!int 3
	      g: !!map
		something: !!str cool

   Set double quote style
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f:
		- 1
		- 2
		- 3
	      g:
		something: cool

       then

	      yq '.. style="double"' sample.yml

       will output

	      a: "cat"
	      b: "5"
	      c: "3.2"
	      e: "true"
	      f:
		- "1"
		- "2"
		- "3"
	      g:
		something: "cool"

   Set double quote style on map keys too
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f:
		- 1
		- 2
		- 3
	      g:
		something: cool

       then

	      yq '... style="double"' sample.yml

       will output

	      "a": "cat"
	      "b": "5"
	      "c": "3.2"
	      "e": "true"
	      "f":
		- "1"
		- "2"
		- "3"
	      "g":
		"something": "cool"

   Set single quote style
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f:
		- 1
		- 2
		- 3
	      g:
		something: cool

       then

	      yq '.. style="single"' sample.yml

       will output

	      a: 'cat'
	      b: '5'
	      c: '3.2'
	      e: 'true'
	      f:
		- '1'
		- '2'
		- '3'
	      g:
		something: 'cool'

   Set literal quote style
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f:
		- 1
		- 2
		- 3
	      g:
		something: cool

       then

	      yq '.. style="literal"' sample.yml

       will output

	      a: |-
		cat
	      b: |-
		5
	      c: |-
		3.2
	      e: |-
		true
	      f:
		- |-
		  1
		- |-
		  2
		- |-
		  3
	      g:
		something: |-
		  cool

   Set folded quote style
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f:
		- 1
		- 2
		- 3
	      g:
		something: cool

       then

	      yq '.. style="folded"' sample.yml

       will output

	      a: >-
		cat
	      b: >-
		5
	      c: >-
		3.2
	      e: >-
		true
	      f:
		- >-
		  1
		- >-
		  2
		- >-
		  3
	      g:
		something: >-
		  cool

   Set flow quote style
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f:
		- 1
		- 2
		- 3
	      g:
		something: cool

       then

	      yq '.. style="flow"' sample.yml

       will output

	      {a: cat, b: 5, c: 3.2, e: true, f: [1, 2, 3], g: {something: cool}}

   Reset style - or pretty print
       Set empty (default) quote style, note the usage of ... to match keys
       too.  Note that there is a --prettyPrint/-P short flag for this.

       Given a sample.yml file of:

	      {a: cat, "b": 5, 'c': 3.2, "e": true,  f: [1,2,3], "g": { something: "cool"} }

       then

	      yq '... style=""' sample.yml

       will output

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f:
		- 1
		- 2
		- 3
	      g:
		something: cool

   Set style relatively with assign-update
       Given a sample.yml file of:

	      a: single
	      b: double

       then

	      yq '.[] style |= .' sample.yml

       will output

	      a: 'single'
	      b: "double"

   Read style
       Given a sample.yml file of:

	      {a: "cat", b: 'thing'}

       then

	      yq '.. | style' sample.yml

       will output

	      flow
	      double
	      single

Subtract
       You can use subtract to subtract numbers as well as remove elements
       from an array.

   Array subtraction
       Running

	      yq --null-input '[1,2] - [2,3]'

       will output

	      - 1

   Array subtraction with nested array
       Running

	      yq --null-input '[[1], 1, 2] - [[1], 3]'

       will output

	      - 1
	      - 2

   Array subtraction with nested object
       Note that order of the keys does not matter

       Given a sample.yml file of:

	      - a: b
		c: d
	      - a: b

       then

	      yq '. - [{"c": "d", "a": "b"}]' sample.yml

       will output

	      - a: b

   Number subtraction - float
       If the lhs or rhs are floats then the expression will be calculated
       with floats.

       Given a sample.yml file of:

	      a: 3
	      b: 4.5

       then

	      yq '.a = .a - .b' sample.yml

       will output

	      a: -1.5
	      b: 4.5

   Number subtraction - int
       If both the lhs and rhs are ints then the expression will be calculated
       with ints.

       Given a sample.yml file of:

	      a: 3
	      b: 4

       then

	      yq '.a = .a - .b' sample.yml

       will output

	      a: -1
	      b: 4

   Decrement numbers
       Given a sample.yml file of:

	      a: 3
	      b: 5

       then

	      yq '.[] -= 1' sample.yml

       will output

	      a: 2
	      b: 4

   Date subtraction
       You can subtract durations from dates.  Assumes RFC3339 date time
       format, see date-time operators
       <https://mikefarah.gitbook.io/yq/operators/date-time-operators> for
       more information.

       Given a sample.yml file of:

	      a: 2021-01-01T03:10:00Z

       then

	      yq '.a -= "3h10m"' sample.yml

       will output

	      a: 2021-01-01T00:00:00Z

   Date subtraction - custom format
       Use with_dtf to specify your datetime format.  See date-time operators
       <https://mikefarah.gitbook.io/yq/operators/date-time-operators> for
       more information.

       Given a sample.yml file of:

	      a: Saturday, 15-Dec-01 at 6:00AM GMT

       then

	      yq 'with_dtf("Monday, 02-Jan-06 at 3:04PM MST", .a -= "3h1m")' sample.yml

       will output

	      a: Saturday, 15-Dec-01 at 2:59AM GMT

   Custom types: that are really numbers
       When custom tags are encountered, yq will try to decode the underlying
       type.

       Given a sample.yml file of:

	      a: !horse 2
	      b: !goat 1

       then

	      yq '.a -= .b' sample.yml

       will output

	      a: !horse 1
	      b: !goat 1

Tag
       The tag operator can be used to get or set the tag of nodes
       (e.g. !!str, !!int, !!bool).

   Get tag
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f: []

       then

	      yq '.. | tag' sample.yml

       will output

	      !!map
	      !!str
	      !!int
	      !!float
	      !!bool
	      !!seq

   type is an alias for tag
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true
	      f: []

       then

	      yq '.. | type' sample.yml

       will output

	      !!map
	      !!str
	      !!int
	      !!float
	      !!bool
	      !!seq

   Set custom tag
       Given a sample.yml file of:

	      a: str

       then

	      yq '.a tag = "!!mikefarah"' sample.yml

       will output

	      a: !!mikefarah str

   Find numbers and convert them to strings
       Given a sample.yml file of:

	      a: cat
	      b: 5
	      c: 3.2
	      e: true

       then

	      yq '(.. | select(tag == "!!int")) tag= "!!str"' sample.yml

       will output

	      a: cat
	      b: "5"
	      c: 3.2
	      e: true

To Number
       Parses the input as a number.  yq will try to parse values as an int
       first, failing that it will try float.  Values that already ints or
       floats will be left alone.

   Converts strings to numbers
       Given a sample.yml file of:

	      - "3"
	      - "3.1"
	      - "-1e3"

       then

	      yq '.[] | to_number' sample.yml

       will output

	      3
	      3.1
	      -1e3

   Doesn’t change numbers
       Given a sample.yml file of:

	      - 3
	      - 3.1
	      - -1e3

       then

	      yq '.[] | to_number' sample.yml

       will output

	      3
	      3.1
	      -1e3

   Cannot convert null
       Running

	      yq --null-input '.a.b | to_number'

       will output

	      Error: cannot convert node value [null] at path a.b of tag !!null to number

Traverse (Read)
       This is the simplest (and perhaps most used) operator.  It is used to
       navigate deeply into yaml structures.

   NOTE –yaml-fix-merge-anchor-to-spec flag
       yq doesn’t merge anchors <<: to spec, in some circumstances it
       incorrectly overrides existing keys when the spec documents not to do
       that.

       To minimise disruption while still fixing the issue, a flag has been
       added to toggle this behaviour.	This will first default to false; and
       log warnings to users.  Then it will default to true (and still allow
       users to specify false if needed)

       See examples of the flag differences below, where LEGACY is the flag
       off; and FIXED is with the flag on.

   Simple map navigation
       Given a sample.yml file of:

	      a:
		b: apple

       then

	      yq '.a' sample.yml

       will output

	      b: apple

   Splat
       Often used to pipe children into other operators

       Given a sample.yml file of:

	      - b: apple
	      - c: banana

       then

	      yq '.[]' sample.yml

       will output

	      b: apple
	      c: banana

   Optional Splat
       Just like splat, but won’t error if you run it against scalars

       Given a sample.yml file of:

	      cat

       then

	      yq '.[]' sample.yml

       will output


   Special characters
       Use quotes with square brackets around path elements with special
       characters

       Given a sample.yml file of:

	      "{}": frog

       then

	      yq '.["{}"]' sample.yml

       will output

	      frog

   Nested special characters
       Given a sample.yml file of:

	      a:
		"key.withdots":
		  "another.key": apple

       then

	      yq '.a["key.withdots"]["another.key"]' sample.yml

       will output

	      apple

   Keys with spaces
       Use quotes with square brackets around path elements with special
       characters

       Given a sample.yml file of:

	      "red rabbit": frog

       then

	      yq '.["red rabbit"]' sample.yml

       will output

	      frog

   Dynamic keys
       Expressions within [] can be used to dynamically lookup / calculate
       keys

       Given a sample.yml file of:

	      b: apple
	      apple: crispy yum
	      banana: soft yum

       then

	      yq '.[.b]' sample.yml

       will output

	      crispy yum

   Children don’t exist
       Nodes are added dynamically while traversing

       Given a sample.yml file of:

	      c: banana

       then

	      yq '.a.b' sample.yml

       will output

	      null

   Optional identifier
       Like jq, does not output an error when the yaml is not an array or
       object as expected

       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3

       then

	      yq '.a?' sample.yml

       will output


   Wildcard matching
       Given a sample.yml file of:

	      a:
		cat: apple
		mad: things

       then

	      yq '.a."*a*"' sample.yml

       will output

	      apple
	      things

   Aliases
       Given a sample.yml file of:

	      a: &cat
		c: frog
	      b: *cat

       then

	      yq '.b' sample.yml

       will output

	      *cat

   Traversing aliases with splat
       Given a sample.yml file of:

	      a: &cat
		c: frog
	      b: *cat

       then

	      yq '.b[]' sample.yml

       will output

	      frog

   Traversing aliases explicitly
       Given a sample.yml file of:

	      a: &cat
		c: frog
	      b: *cat

       then

	      yq '.b.c' sample.yml

       will output

	      frog

   Traversing arrays by index
       Given a sample.yml file of:

	      - 1
	      - 2
	      - 3

       then

	      yq '.[0]' sample.yml

       will output

	      1

   Traversing nested arrays by index
       Given a sample.yml file of:

	      [[], [cat]]

       then

	      yq '.[1][0]' sample.yml

       will output

	      cat

   Maps with numeric keys
       Given a sample.yml file of:

	      2: cat

       then

	      yq '.[2]' sample.yml

       will output

	      cat

   Maps with non existing numeric keys
       Given a sample.yml file of:

	      a: b

       then

	      yq '.[0]' sample.yml

       will output

	      null

   Traversing merge anchors
       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobar.a' sample.yml

       will output

	      foo_a

   Traversing merge anchors with local override
       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobar.thing' sample.yml

       will output

	      foobar_thing

   Select multiple indices
       Given a sample.yml file of:

	      a:
		- a
		- b
		- c

       then

	      yq '.a[0, 2]' sample.yml

       will output

	      a
	      c

   LEGACY: Traversing merge anchors with override
       This is legacy behaviour, see –yaml-fix-merge-anchor-to-spec

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobar.c' sample.yml

       will output

	      foo_c

   LEGACY: Traversing merge anchor lists
       Note that the later merge anchors override previous, but this is legacy
       behaviour, see –yaml-fix-merge-anchor-to-spec

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobarList.thing' sample.yml

       will output

	      bar_thing

   LEGACY: Splatting merge anchors
       With legacy override behaviour, see –yaml-fix-merge-anchor-to-spec

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobar[]' sample.yml

       will output

	      foo_c
	      foo_a
	      foobar_thing

   LEGACY: Splatting merge anchor lists
       With legacy override behaviour, see –yaml-fix-merge-anchor-to-spec

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobarList[]' sample.yml

       will output

	      bar_b
	      foo_a
	      bar_thing
	      foobarList_c

   FIXED: Traversing merge anchors with override
       Set --yaml-fix-merge-anchor-to-spec=true to get this correct merge
       behaviour.

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobar.c' sample.yml

       will output

	      foobar_c

   FIXED: Traversing merge anchor lists
       Set --yaml-fix-merge-anchor-to-spec=true to get this correct merge
       behaviour.  Note that the keys earlier in the merge anchors sequence
       override later ones

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobarList.thing' sample.yml

       will output

	      foo_thing

   FIXED: Splatting merge anchors
       Set --yaml-fix-merge-anchor-to-spec=true to get this correct merge
       behaviour.  Note that the keys earlier in the merge anchors sequence
       override later ones

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobar[]' sample.yml

       will output

	      foo_a
	      foobar_thing
	      foobar_c

   FIXED: Splatting merge anchor lists
       Set --yaml-fix-merge-anchor-to-spec=true to get this correct merge
       behaviour.  Note that the keys earlier in the merge anchors sequence
       override later ones

       Given a sample.yml file of:

	      foo: &foo
		a: foo_a
		thing: foo_thing
		c: foo_c
	      bar: &bar
		b: bar_b
		thing: bar_thing
		c: bar_c
	      foobarList:
		b: foobarList_b
		!!merge <<:
		  - *foo
		  - *bar
		c: foobarList_c
	      foobar:
		c: foobar_c
		!!merge <<: *foo
		thing: foobar_thing

       then

	      yq '.foobarList[]' sample.yml

       will output

	      foobarList_b
	      foo_thing
	      foobarList_c
	      foo_a

Union
       This operator is used to combine different results together.

   Combine scalars
       Running

	      yq --null-input '1, true, "cat"'

       will output

	      1
	      true
	      cat

   Combine selected paths
       Given a sample.yml file of:

	      a: fieldA
	      b: fieldB
	      c: fieldC

       then

	      yq '.a, .c' sample.yml

       will output

	      fieldA
	      fieldC

Unique
       This is used to filter out duplicated items in an array.  Note that the
       original order of the array is maintained.

   Unique array of scalars (string/numbers)
       Note that unique maintains the original order of the array.

       Given a sample.yml file of:

	      - 2
	      - 1
	      - 3
	      - 2

       then

	      yq 'unique' sample.yml

       will output

	      - 2
	      - 1
	      - 3

   Unique nulls
       Unique works on the node value, so it considers different
       representations of nulls to be different

       Given a sample.yml file of:

	      - ~
	      - null
	      - ~
	      - null

       then

	      yq 'unique' sample.yml

       will output

	      - ~
	      - null

   Unique all nulls
       Run against the node tag to unique all the nulls

       Given a sample.yml file of:

	      - ~
	      - null
	      - ~
	      - null

       then

	      yq 'unique_by(tag)' sample.yml

       will output

	      - ~

   Unique array objects
       Given a sample.yml file of:

	      - name: harry
		pet: cat
	      - name: billy
		pet: dog
	      - name: harry
		pet: cat

       then

	      yq 'unique' sample.yml

       will output

	      - name: harry
		pet: cat
	      - name: billy
		pet: dog

   Unique array of objects by a field
       Given a sample.yml file of:

	      - name: harry
		pet: cat
	      - name: billy
		pet: dog
	      - name: harry
		pet: dog

       then

	      yq 'unique_by(.name)' sample.yml

       will output

	      - name: harry
		pet: cat
	      - name: billy
		pet: dog

   Unique array of arrays
       Given a sample.yml file of:

	      - - cat
		- dog
	      - - cat
		- sheep
	      - - cat
		- dog

       then

	      yq 'unique' sample.yml

       will output

	      - - cat
		- dog
	      - - cat
		- sheep

Variable Operators
       Like the jq equivalents, variables are sometimes required for the more
       complex expressions (or swapping values between fields).

       Note that there is also an additional ref operator that holds a
       reference (instead of a copy) of the path, allowing you to make
       multiple changes to the same path.

   Single value variable
       Given a sample.yml file of:

	      a: cat

       then

	      yq '.a as $foo | $foo' sample.yml

       will output

	      cat

   Multi value variable
       Given a sample.yml file of:

	      - cat
	      - dog

       then

	      yq '.[] as $foo | $foo' sample.yml

       will output

	      cat
	      dog

   Using variables as a lookup
       Example taken from jq
       <https://stedolan.github.io/jq/manual/#Variable/SymbolicBindingOperator:...as$identifier%7C...>

       Given a sample.yml file of:

	      "posts":
		- "title": First post
		  "author": anon
		- "title": A well-written article
		  "author": person1
	      "realnames":
		"anon": Anonymous Coward
		"person1": Person McPherson

       then

	      yq '.realnames as $names | .posts[] | {"title":.title, "author": $names[.author]}' sample.yml

       will output

	      title: First post
	      author: Anonymous Coward
	      title: A well-written article
	      author: Person McPherson

   Using variables to swap values
       Given a sample.yml file of:

	      a: a_value
	      b: b_value

       then

	      yq '.a as $x  | .b as $y | .b = $x | .a = $y' sample.yml

       will output

	      a: b_value
	      b: a_value

   Use ref to reference a path repeatedly
       Note: You may find the with operator more useful.

       Given a sample.yml file of:

	      a:
		b: thing
		c: something

       then

	      yq '.a.b ref $x | $x = "new" | $x style="double"' sample.yml

       will output

	      a:
		b: "new"
		c: something

With
       Use the with operator to conveniently make multiple updates to a deeply
       nested path, or to update array elements relatively to each other.  The
       first argument expression sets the root context, and the second
       expression runs against that root context.

   Update and style
       Given a sample.yml file of:

	      a:
		deeply:
		  nested: value

       then

	      yq 'with(.a.deeply.nested; . = "newValue" | . style="single")' sample.yml

       will output

	      a:
		deeply:
		  nested: 'newValue'

   Update multiple deeply nested properties
       Given a sample.yml file of:

	      a:
		deeply:
		  nested: value
		  other: thing

       then

	      yq 'with(.a.deeply; .nested = "newValue" | .other= "newThing")' sample.yml

       will output

	      a:
		deeply:
		  nested: newValue
		  other: newThing

   Update array elements relatively
       The second expression runs with each element of the array as it’s
       contextual root.  This allows you to make updates relative to the
       element.

       Given a sample.yml file of:

	      myArray:
		- a: apple
		- a: banana

       then

	      yq 'with(.myArray[]; .b = .a + " yum")' sample.yml

       will output

	      myArray:
		- a: apple
		  b: apple yum
		- a: banana
		  b: banana yum

Base64
       Encode and decode to and from Base64.

       Base64 assumes RFC4648
       <https://rfc-editor.org/rfc/rfc4648.html> encoding.  Encoding and
       decoding both assume that the content is a UTF-8 string and not binary
       content.

       See below for examples

   Decode base64: simple
       Decoded data is assumed to be a string.

       Given a sample.txt file of:

	      YSBzcGVjaWFsIHN0cmluZw==

       then

	      yq -p=base64 -oy '.' sample.txt

       will output

	      a special string

   Decode base64: UTF-8
       Base64 decoding supports UTF-8 encoded strings.

       Given a sample.txt file of:

	      V29ya3Mgd2l0aCBVVEYtMTYg8J+Yig==

       then

	      yq -p=base64 -oy '.' sample.txt

       will output

	      Works with UTF-16 😊

   Decode with extra spaces
       Extra leading/trailing whitespace is stripped

       Given a sample.txt file of:


	       YSBzcGVjaWFsIHN0cmluZw==

       then

	      yq -p=base64 -oy '.' sample.txt

       will output

	      a special string

   Encode base64: string
       Given a sample.yml file of:

	      "a special string"

       then

	      yq -o=base64 '.' sample.yml

       will output

	      YSBzcGVjaWFsIHN0cmluZw==```

	      ## Encode base64: string from document
	      Extract a string field and encode it to base64.

	      Given a sample.yml file of:
	      ```yaml
	      coolData: "a special string"

       then

	      yq -o=base64 '.coolData' sample.yml

       will output

	      YSBzcGVjaWFsIHN0cmluZw==```

	      # JSON

	      Encode and decode to and from JSON. Supports multiple JSON documents in a single file (e.g. NDJSON).

	      Note that YAML is a superset of (single document) JSON - so you don't have to use the JSON parser to read JSON when there is only one JSON document in the input. You will probably want to pretty print the result in this case, to get idiomatic YAML styling.


	      ## Parse json: simple
	      JSON is a subset of yaml, so all you need to do is prettify the output

	      Given a sample.json file of:
	      ```json
	      {"cat": "meow"}

       then

	      yq -p=json sample.json

       will output

	      cat: meow

   Parse json: complex
       JSON is a subset of yaml, so all you need to do is prettify the output

       Given a sample.json file of:

	      {"a":"Easy! as one two three","b":{"c":2,"d":[3,4]}}

       then

	      yq -p=json sample.json

       will output

	      a: Easy! as one two three
	      b:
		c: 2
		d:
		  - 3
		  - 4

   Encode json: simple
       Given a sample.yml file of:

	      cat: meow

       then

	      yq -o=json '.' sample.yml

       will output

	      {
		"cat": "meow"
	      }

   Encode json: simple - in one line
       Given a sample.yml file of:

	      cat: meow # this is a comment, and it will be dropped.

       then

	      yq -o=json -I=0 '.' sample.yml

       will output

	      {"cat":"meow"}

   Encode json: comments
       Given a sample.yml file of:

	      cat: meow # this is a comment, and it will be dropped.

       then

	      yq -o=json '.' sample.yml

       will output

	      {
		"cat": "meow"
	      }

   Encode json: anchors
       Anchors are dereferenced

       Given a sample.yml file of:

	      cat: &ref meow
	      anotherCat: *ref

       then

	      yq -o=json '.' sample.yml

       will output

	      {
		"cat": "meow",
		"anotherCat": "meow"
	      }

   Encode json: multiple results
       Each matching node is converted into a json doc.  This is best used
       with 0 indent (json document per line)

       Given a sample.yml file of:

	      things: [{stuff: cool}, {whatever: cat}]

       then

	      yq -o=json -I=0 '.things[]' sample.yml

       will output

	      {"stuff":"cool"}
	      {"whatever":"cat"}

   Roundtrip JSON Lines / NDJSON
       Given a sample.json file of:

	      {"this": "is a multidoc json file"}
	      {"each": ["line is a valid json document"]}
	      {"a number": 4}

       then

	      yq -p=json -o=json -I=0 sample.json

       will output

	      {"this":"is a multidoc json file"}
	      {"each":["line is a valid json document"]}
	      {"a number":4}

   Roundtrip multi-document JSON
       The parser can also handle multiple multi-line json documents in a
       single file (despite this not being in the JSON Lines / NDJSON spec).
       Typically you would have one entire JSON document per line, but the
       parser also supports multiple multi-line json documents

       Given a sample.json file of:

	      {
		  "this": "is a multidoc json file"
	      }
	      {
		  "it": [
		      "has",
		      "consecutive",
		      "json documents"
		  ]
	      }
	      {
		  "a number": 4
	      }

       then

	      yq -p=json -o=json -I=2 sample.json

       will output

	      {
		"this": "is a multidoc json file"
	      }
	      {
		"it": [
		  "has",
		  "consecutive",
		  "json documents"
		]
	      }
	      {
		"a number": 4
	      }

   Update a specific document in a multi-document json
       Documents are indexed by the documentIndex or di operator.

       Given a sample.json file of:

	      {"this": "is a multidoc json file"}
	      {"each": ["line is a valid json document"]}
	      {"a number": 4}

       then

	      yq -p=json -o=json -I=0 '(select(di == 1) | .each ) += "cool"' sample.json

       will output

	      {"this":"is a multidoc json file"}
	      {"each":["line is a valid json document","cool"]}
	      {"a number":4}

   Find and update a specific document in a multi-document json
       Use expressions as you normally would.

       Given a sample.json file of:

	      {"this": "is a multidoc json file"}
	      {"each": ["line is a valid json document"]}
	      {"a number": 4}

       then

	      yq -p=json -o=json -I=0 '(select(has("each")) | .each ) += "cool"' sample.json

       will output

	      {"this":"is a multidoc json file"}
	      {"each":["line is a valid json document","cool"]}
	      {"a number":4}

   Decode JSON Lines / NDJSON
       Given a sample.json file of:

	      {"this": "is a multidoc json file"}
	      {"each": ["line is a valid json document"]}
	      {"a number": 4}

       then

	      yq -p=json sample.json

       will output

	      this: is a multidoc json file
	      ---
	      each:
		- line is a valid json document
	      ---
	      a number: 4

CSV
       Encode/Decode/Roundtrip CSV and TSV files.

   Encode
       Currently supports arrays of homogeneous flat objects, that is: no
       nesting and it assumes the first object has all the keys required:

	      - name: Bobo
		type: dog
	      - name: Fifi
		type: cat

       As well as arrays of arrays of scalars (strings/numbers/booleans):

	      - [Bobo, dog]
	      - [Fifi, cat]

   Decode
       Decode assumes the first CSV/TSV row is the header row, and all rows
       beneath are the entries.  The data will be coded into an array of
       objects, using the header rows as keys.

	      name,type
	      Bobo,dog
	      Fifi,cat

   Encode CSV simple
       Given a sample.yml file of:

	      - [i, like, csv]
	      - [because, excel, is, cool]

       then

	      yq -o=csv sample.yml

       will output

	      i,like,csv
	      because,excel,is,cool

   Encode TSV simple
       Given a sample.yml file of:

	      - [i, like, csv]
	      - [because, excel, is, cool]

       then

	      yq -o=tsv sample.yml

       will output

	      i   like	  csv
	      because excel   is  cool

   Encode array of objects to csv
       Given a sample.yml file of:

	      - name: Gary
		numberOfCats: 1
		likesApples: true
		height: 168.8
	      - name: Samantha's Rabbit
		numberOfCats: 2
		likesApples: false
		height: -188.8

       then

	      yq -o=csv sample.yml

       will output

	      name,numberOfCats,likesApples,height
	      Gary,1,true,168.8
	      Samantha's Rabbit,2,false,-188.8

   Encode array of objects to custom csv format
       Add the header row manually, then the we convert each object into an
       array of values - resulting in an array of arrays.  Pick the columns
       and call the header whatever you like.

       Given a sample.yml file of:

	      - name: Gary
		numberOfCats: 1
		likesApples: true
		height: 168.8
	      - name: Samantha's Rabbit
		numberOfCats: 2
		likesApples: false
		height: -188.8

       then

	      yq -o=csv '[["Name", "Number of Cats"]] +  [.[] | [.name, .numberOfCats ]]' sample.yml

       will output

	      Name,Number of Cats
	      Gary,1
	      Samantha's Rabbit,2

   Encode array of objects to csv - missing fields behaviour
       First entry is used to determine the headers, and it is missing
       `likesApples', so it is not included in the csv.  Second entry does not
       have `numberOfCats' so that is blank

       Given a sample.yml file of:

	      - name: Gary
		numberOfCats: 1
		height: 168.8
	      - name: Samantha's Rabbit
		height: -188.8
		likesApples: false

       then

	      yq -o=csv sample.yml

       will output

	      name,numberOfCats,height
	      Gary,1,168.8
	      Samantha's Rabbit,,-188.8

   Parse CSV into an array of objects
       First row is assumed to be the header row.  By default, entries with
       YAML/JSON formatting will be parsed!

       Given a sample.csv file of:

	      name,numberOfCats,likesApples,height,facts
	      Gary,1,true,168.8,cool: true
	      Samantha's Rabbit,2,false,-188.8,tall: indeed

       then

	      yq -p=csv sample.csv

       will output

	      - name: Gary
		numberOfCats: 1
		likesApples: true
		height: 168.8
		facts:
		  cool: true
	      - name: Samantha's Rabbit
		numberOfCats: 2
		likesApples: false
		height: -188.8
		facts:
		  tall: indeed

   Parse CSV into an array of objects, no auto-parsing
       First row is assumed to be the header row.  Entries with YAML/JSON will
       be left as strings.

       Given a sample.csv file of:

	      name,numberOfCats,likesApples,height,facts
	      Gary,1,true,168.8,cool: true
	      Samantha's Rabbit,2,false,-188.8,tall: indeed

       then

	      yq -p=csv --csv-auto-parse=f sample.csv

       will output

	      - name: Gary
		numberOfCats: 1
		likesApples: true
		height: 168.8
		facts: 'cool: true'
	      - name: Samantha's Rabbit
		numberOfCats: 2
		likesApples: false
		height: -188.8
		facts: 'tall: indeed'

   Parse TSV into an array of objects
       First row is assumed to be the header row.

       Given a sample.tsv file of:

	      name    numberOfCats    likesApples height
	      Gary    1   true	  168.8
	      Samantha's Rabbit   2   false   -188.8

       then

	      yq -p=tsv sample.tsv

       will output

	      - name: Gary
		numberOfCats: 1
		likesApples: true
		height: 168.8
	      - name: Samantha's Rabbit
		numberOfCats: 2
		likesApples: false
		height: -188.8

   Round trip
       Given a sample.csv file of:

	      name,numberOfCats,likesApples,height
	      Gary,1,true,168.8
	      Samantha's Rabbit,2,false,-188.8

       then

	      yq -p=csv -o=csv '(.[] | select(.name == "Gary") | .numberOfCats) = 3' sample.csv

       will output

	      name,numberOfCats,likesApples,height
	      Gary,3,true,168.8
	      Samantha's Rabbit,2,false,-188.8

Formatting Expressions
       From version v4.41+

       You can put expressions into .yq files, use whitespace and comments to
       break up complex expressions and explain what’s going on.

   Using expression files and comments
       Note that you can execute the file directly - but make sure you make
       the expression file executable.

       Given a sample.yaml file of:

	      a:
		b: old

       And an `update.yq' expression file of:

	      #! yq

	      # This is a yq expression that updates the map
	      # for several great reasons outlined here.

	      .a.b = "new" # line comment here
	      | .a.c = "frog"

	      # Now good things will happen.

       then

	      ./update.yq sample.yaml

       will output

	      a:
		b: new
		c: frog

   Flags in expression files
       You can specify flags on the shebang line, this only works when
       executing the file directly.

       Given a sample.yaml file of:

	      a:
		b: old

       And an `update.yq' expression file of:

	      #! yq -oj

	      # This is a yq expression that updates the map
	      # for several great reasons outlined here.

	      .a.b = "new" # line comment here
	      | .a.c = "frog"

	      # Now good things will happen.

       then

	      ./update.yq sample.yaml

       will output

	      {
		"a": {
		  "b": "new",
		  "c": "frog"
		}
	      }

   Commenting out yq expressions
       Note that c is no longer set to `frog'.	In this example we’re calling
       yq directly and passing the expression file into --from-file, this is
       no different from executing the expression file directly.

       Given a sample.yaml file of:

	      a:
		b: old

       And an `update.yq' expression file of:

	      #! yq
	      # This is a yq expression that updates the map
	      # for several great reasons outlined here.

	      .a.b = "new" # line comment here
	      # | .a.c = "frog"

	      # Now good things will happen.

       then

	      yq --from-file update.yq sample.yml

       will output

	      a:
		b: new

HCL
       Encode and decode to and from HashiCorp Configuration Language (HCL)
       <https://github.com/hashicorp/hcl>.

       HCL is commonly used in HashiCorp tools like Terraform for
       configuration files.  The yq HCL encoder and decoder support: - Blocks
       and attributes - String interpolation and expressions (preserved
       without quotes) - Comments (leading, head, and line comments) - Nested
       structures (maps and lists) - Syntax colorization when enabled

   Parse HCL
       Given a sample.hcl file of:

	      io_mode = "async"

       then

	      yq -oy sample.hcl

       will output

	      io_mode: "async"

   Roundtrip: Sample Doc
       Given a sample.hcl file of:

	      service "cat" {
		process "main" {
		  command = ["/usr/local/bin/awesome-app", "server"]
		}

		process "management" {
		  command = ["/usr/local/bin/awesome-app", "management"]
		}
	      }

       then

	      yq sample.hcl

       will output

	      service "cat" {
		process "main" {
		  command = ["/usr/local/bin/awesome-app", "server"]
		}
		process "management" {
		  command = ["/usr/local/bin/awesome-app", "management"]
		}
	      }

   Roundtrip: With an update
       Given a sample.hcl file of:

	      service "cat" {
		process "main" {
		  command = ["/usr/local/bin/awesome-app", "server"]
		}

		process "management" {
		  command = ["/usr/local/bin/awesome-app", "management"]
		}
	      }

       then

	      yq '.service.cat.process.main.command += "meow"' sample.hcl

       will output

	      service "cat" {
		process "main" {
		  command = ["/usr/local/bin/awesome-app", "server", "meow"]
		}
		process "management" {
		  command = ["/usr/local/bin/awesome-app", "management"]
		}
	      }

   Parse HCL: Sample Doc
       Given a sample.hcl file of:

	      service "cat" {
		process "main" {
		  command = ["/usr/local/bin/awesome-app", "server"]
		}

		process "management" {
		  command = ["/usr/local/bin/awesome-app", "management"]
		}
	      }

       then

	      yq -oy sample.hcl

       will output

	      service:
		cat:
		  process:
		    main:
		      command:
			- "/usr/local/bin/awesome-app"
			- "server"
		    management:
		      command:
			- "/usr/local/bin/awesome-app"
			- "management"

   Parse HCL: with comments
       Given a sample.hcl file of:

	      # Configuration
	      port = 8080 # server port

       then

	      yq -oy sample.hcl

       will output

	      # Configuration
	      port: 8080 # server port

   Roundtrip: with comments
       Given a sample.hcl file of:

	      # Configuration
	      port = 8080

       then

	      yq sample.hcl

       will output

	      # Configuration
	      port = 8080

   Roundtrip: With templates, functions and arithmetic
       Given a sample.hcl file of:

	      # Arithmetic with literals and application-provided variables
	      sum = 1 + addend

	      # String interpolation and templates
	      message = "Hello, ${name}!"

	      # Application-provided functions
	      shouty_message = upper(message)

       then

	      yq sample.hcl

       will output

	      # Arithmetic with literals and application-provided variables
	      sum = 1 + addend
	      # String interpolation and templates
	      message = "Hello, ${name}!"
	      # Application-provided functions
	      shouty_message = upper(message)

   Roundtrip: Separate blocks with same name.
       Given a sample.hcl file of:

	      resource "aws_instance" "web" {
		ami = "ami-12345"
	      }
	      resource "aws_instance" "db" {
		ami = "ami-67890"
	      }

       then

	      yq sample.hcl

       will output

	      resource "aws_instance" "web" {
		ami = "ami-12345"
	      }
	      resource "aws_instance" "db" {
		ami = "ami-67890"
	      }

   Basic input example
       Given a sample.lua file of:

	      return {
		  ["country"] = "Australia"; -- this place
		  ["cities"] = {
		      "Sydney",
		      "Melbourne",
		      "Brisbane",
		      "Perth",
		  };
	      };

       then

	      yq -oy '.' sample.lua

       will output

	      country: Australia
	      cities:
		- Sydney
		- Melbourne
		- Brisbane
		- Perth

   Basic output example
       Given a sample.yml file of:

	      ---
	      country: Australia # this place
	      cities:
	      - Sydney
	      - Melbourne
	      - Brisbane
	      - Perth

       then

	      yq -o=lua '.' sample.yml

       will output

	      return {
		  ["country"] = "Australia"; -- this place
		  ["cities"] = {
		      "Sydney",
		      "Melbourne",
		      "Brisbane",
		      "Perth",
		  };
	      };

   Unquoted keys
       Uses the --lua-unquoted option to produce a nicer-looking output.

       Given a sample.yml file of:

	      ---
	      country: Australia # this place
	      cities:
	      - Sydney
	      - Melbourne
	      - Brisbane
	      - Perth

       then

	      yq -o=lua --lua-unquoted '.' sample.yml

       will output

	      return {
		  country = "Australia"; -- this place
		  cities = {
		      "Sydney",
		      "Melbourne",
		      "Brisbane",
		      "Perth",
		  };
	      };

   Globals
       Uses the --lua-globals option to export the values into the global
       scope.

       Given a sample.yml file of:

	      ---
	      country: Australia # this place
	      cities:
	      - Sydney
	      - Melbourne
	      - Brisbane
	      - Perth

       then

	      yq -o=lua --lua-globals '.' sample.yml

       will output

	      country = "Australia"; -- this place
	      cities = {
		  "Sydney",
		  "Melbourne",
		  "Brisbane",
		  "Perth",
	      };

   Elaborate example
       Given a sample.yml file of:

	      ---
	      hello: world
	      tables:
		like: this
		keys: values
		? look: non-string keys
		: True
	      numbers:
		- decimal: 12345
		- hex: 0x7fabc123
		- octal: 0o30
		- float: 123.45
		- infinity: .inf
		  plus_infinity: +.inf
		  minus_infinity: -.inf
		- not: .nan

       then

	      yq -o=lua '.' sample.yml

       will output

	      return {
		  ["hello"] = "world";
		  ["tables"] = {
		      ["like"] = "this";
		      ["keys"] = "values";
		      [{
			  ["look"] = "non-string keys";
		      }] = true;
		  };
		  ["numbers"] = {
		      {
			  ["decimal"] = 12345;
		      },
		      {
			  ["hex"] = 0x7fabc123;
		      },
		      {
			  ["octal"] = 24;
		      },
		      {
			  ["float"] = 123.45;
		      },
		      {
			  ["infinity"] = (1/0);
			  ["plus_infinity"] = (1/0);
			  ["minus_infinity"] = (-1/0);
		      },
		      {
			  ["not"] = (0/0);
		      },
		  };
	      };

Properties
       Encode/Decode/Roundtrip to/from a property file.  Line comments on
       value nodes will be copied across.

       By default, empty maps and arrays are not encoded - see below for an
       example on how to encode a value for these.

   Encode properties
       Note that empty arrays and maps are not encoded by default.

       Given a sample.yml file of:

	      # block comments come through
	      person: # neither do comments on maps
		  name: Mike Wazowski # comments on values appear
		  pets:
		  - cat # comments on array values appear
		  - nested:
		      - list entry
		  food: [pizza] # comments on arrays do not
	      emptyArray: []
	      emptyMap: []

       then

	      yq -o=props sample.yml

       will output

	      # block comments come through
	      # comments on values appear
	      person.name = Mike Wazowski

	      # comments on array values appear
	      person.pets.0 = cat
	      person.pets.1.nested.0 = list entry
	      person.food.0 = pizza

   Encode properties with array brackets
       Declare the –properties-array-brackets flag to give array paths in
       brackets (e.g. SpringBoot).

       Given a sample.yml file of:

	      # block comments come through
	      person: # neither do comments on maps
		  name: Mike Wazowski # comments on values appear
		  pets:
		  - cat # comments on array values appear
		  - nested:
		      - list entry
		  food: [pizza] # comments on arrays do not
	      emptyArray: []
	      emptyMap: []

       then

	      yq -o=props --properties-array-brackets sample.yml

       will output

	      # block comments come through
	      # comments on values appear
	      person.name = Mike Wazowski

	      # comments on array values appear
	      person.pets[0] = cat
	      person.pets[1].nested[0] = list entry
	      person.food[0] = pizza

   Encode properties - custom separator
       Use the –properties-separator flag to specify your own key/value
       separator.

       Given a sample.yml file of:

	      # block comments come through
	      person: # neither do comments on maps
		  name: Mike Wazowski # comments on values appear
		  pets:
		  - cat # comments on array values appear
		  - nested:
		      - list entry
		  food: [pizza] # comments on arrays do not
	      emptyArray: []
	      emptyMap: []

       then

	      yq -o=props --properties-separator=" :@ " sample.yml

       will output

	      # block comments come through
	      # comments on values appear
	      person.name :@ Mike Wazowski

	      # comments on array values appear
	      person.pets.0 :@ cat
	      person.pets.1.nested.0 :@ list entry
	      person.food.0 :@ pizza

   Encode properties: scalar encapsulation
       Note that string values with blank characters in them are encapsulated
       with double quotes

       Given a sample.yml file of:

	      # block comments come through
	      person: # neither do comments on maps
		  name: Mike Wazowski # comments on values appear
		  pets:
		  - cat # comments on array values appear
		  - nested:
		      - list entry
		  food: [pizza] # comments on arrays do not
	      emptyArray: []
	      emptyMap: []

       then

	      yq -o=props --unwrapScalar=false sample.yml

       will output

	      # block comments come through
	      # comments on values appear
	      person.name = "Mike Wazowski"

	      # comments on array values appear
	      person.pets.0 = cat
	      person.pets.1.nested.0 = "list entry"
	      person.food.0 = pizza

   Encode properties: no comments
       Given a sample.yml file of:

	      # block comments come through
	      person: # neither do comments on maps
		  name: Mike Wazowski # comments on values appear
		  pets:
		  - cat # comments on array values appear
		  - nested:
		      - list entry
		  food: [pizza] # comments on arrays do not
	      emptyArray: []
	      emptyMap: []

       then

	      yq -o=props '... comments = ""' sample.yml

       will output

	      person.name = Mike Wazowski
	      person.pets.0 = cat
	      person.pets.1.nested.0 = list entry
	      person.food.0 = pizza

   Encode properties: include empty maps and arrays
       Use a yq expression to set the empty maps and sequences to your desired
       value.

       Given a sample.yml file of:

	      # block comments come through
	      person: # neither do comments on maps
		  name: Mike Wazowski # comments on values appear
		  pets:
		  - cat # comments on array values appear
		  - nested:
		      - list entry
		  food: [pizza] # comments on arrays do not
	      emptyArray: []
	      emptyMap: []

       then

	      yq -o=props '(.. | select( (tag == "!!map" or tag =="!!seq") and length == 0)) = ""' sample.yml

       will output

	      # block comments come through
	      # comments on values appear
	      person.name = Mike Wazowski

	      # comments on array values appear
	      person.pets.0 = cat
	      person.pets.1.nested.0 = list entry
	      person.food.0 = pizza
	      emptyArray =
	      emptyMap =

   Decode properties
       Given a sample.properties file of:

	      # block comments come through
	      # comments on values appear
	      person.name = Mike Wazowski

	      # comments on array values appear
	      person.pets.0 = cat
	      person.pets.1.nested.0 = list entry
	      person.food.0 = pizza

       then

	      yq -p=props sample.properties

       will output

	      person:
		# block comments come through
		# comments on values appear
		name: Mike Wazowski
		pets:
		  # comments on array values appear
		  - cat
		  - nested:
		      - list entry
		food:
		  - pizza

   Decode properties: numbers
       All values are assumed to be strings when parsing properties, but you
       can use the from_yaml operator on all the strings values to autoparse
       into the correct type.

       Given a sample.properties file of:

	      a.b = 10

       then

	      yq -p=props ' (.. | select(tag == "!!str")) |= from_yaml' sample.properties

       will output

	      a:
		b: 10

   Decode properties - array should be a map
       If you have a numeric map key in your property files, use array_to_map
       to convert them to maps.

       Given a sample.properties file of:

	      things.10 = mike

       then

	      yq -p=props '.things |= array_to_map' sample.properties

       will output

	      things:
		10: mike

   Roundtrip
       Given a sample.properties file of:

	      # block comments come through
	      # comments on values appear
	      person.name = Mike Wazowski

	      # comments on array values appear
	      person.pets.0 = cat
	      person.pets.1.nested.0 = list entry
	      person.food.0 = pizza

       then

	      yq -p=props -o=props '.person.pets.0 = "dog"' sample.properties

       will output

	      # block comments come through
	      # comments on values appear
	      person.name = Mike Wazowski

	      # comments on array values appear
	      person.pets.0 = dog
	      person.pets.1.nested.0 = list entry
	      person.food.0 = pizza

Recipes
       These examples are intended to show how you can use multiple operators
       together so you get an idea of how you can perform complex data
       manipulation.

       Please see the details operator docs
       <https://mikefarah.gitbook.io/yq/operators> for details on each
       individual operator.

   Find items in an array
       We have an array and we want to find the elements with a particular
       name.

       Given a sample.yml file of:

	      - name: Foo
		numBuckets: 0
	      - name: Bar
		numBuckets: 0

       then

	      yq '.[] | select(.name == "Foo")' sample.yml

       will output

	      name: Foo
	      numBuckets: 0

   Explanation:
       • .[] splats the array, and puts all the items in the context.

       • These items are then piped (|) into select(.name == "Foo") which will
	 select all the nodes that have a name property set to `Foo'.

       • See the select
	 <https://mikefarah.gitbook.io/yq/operators/select> operator for more
	 information.

   Find and update items in an array
       We have an array and we want to update the elements with a particular
       name.

       Given a sample.yml file of:

	      - name: Foo
		numBuckets: 0
	      - name: Bar
		numBuckets: 0

       then

	      yq '(.[] | select(.name == "Foo") | .numBuckets) |= . + 1' sample.yml

       will output

	      - name: Foo
		numBuckets: 1
	      - name: Bar
		numBuckets: 0

   Explanation:
       • Following from the example above.[] splats the array, selects filters
	 the items.

       • We then pipe (|) that into .numBuckets, which will select that field
	 from all the matching items

       • Splat, select and the field are all in brackets, that whole
	 expression is passed to the |= operator as the left hand side
	 expression, with . + 1 as the right hand side expression.

       • |= is the operator that updates fields relative to their own value,
	 which is referenced as dot (.).

       • The expression . + 1 increments the numBuckets counter.

       • See the assign
	 <https://mikefarah.gitbook.io/yq/operators/assign-update> and add
	 <https://mikefarah.gitbook.io/yq/operators/add> operators for more
	 information.

   Deeply prune a tree
       Say we are only interested in child1 and child2, and want to filter
       everything else out.

       Given a sample.yml file of:

	      parentA:
		- bob
	      parentB:
		child1: i am child1
		child3: hiya
	      parentC:
		childX: cool
		child2: me child2

       then

	      yq '(
		.. | # recurse through all the nodes
		select(has("child1") or has("child2")) | # match parents that have either child1 or child2
		(.child1, .child2) | # select those children
		select(.) # filter out nulls
	      ) as $i ireduce({};  # using that set of nodes, create a new result map
		setpath($i | path; $i) # and put in each node, using its original path
	      )' sample.yml

       will output

	      parentB:
		child1: i am child1
	      parentC:
		child2: me child2

   Explanation:
       • Find all the matching child1 and child2 nodes

       • Using ireduce, create a new map using just those nodes

       • Set each node into the new map using its original path

   Multiple or complex updates to items in an array
       We have an array and we want to update the elements with a particular
       name in reference to its type.

       Given a sample.yml file of:

	      myArray:
		- name: Foo
		  type: cat
		- name: Bar
		  type: dog

       then

	      yq 'with(.myArray[]; .name = .name + " - " + .type)' sample.yml

       will output

	      myArray:
		- name: Foo - cat
		  type: cat
		- name: Bar - dog
		  type: dog

   Explanation:
       • The with operator will effectively loop through each given item in
	 the first given expression, and run the second expression against it.

       • .myArray[] splats the array in myArray.  So with will run against
	 each item in that array

       • .name = .name + " - " + .type this expression is run against every
	 item, updating the name to be a concatenation of the original name as
	 well as the type.

       • See the with
	 <https://mikefarah.gitbook.io/yq/operators/with> operator for more
	 information and examples.

   Sort an array by a field
       Given a sample.yml file of:

	      myArray:
		- name: Foo
		  numBuckets: 1
		- name: Bar
		  numBuckets: 0

       then

	      yq '.myArray |= sort_by(.numBuckets)' sample.yml

       will output

	      myArray:
		- name: Bar
		  numBuckets: 0
		- name: Foo
		  numBuckets: 1

   Explanation:
       • We want to resort .myArray.

       • sort_by works by piping an array into it, and it pipes out a sorted
	 array.

       • So, we use |= to update .myArray.  This is the same as doing .myArray
	 = (.myArray | sort_by(.numBuckets))

   Filter, flatten, sort and unique
       Lets find the unique set of names from the document.

       Given a sample.yml file of:

	      - type: foo
		names:
		  - Fred
		  - Catherine
	      - type: bar
		names:
		  - Zelda
	      - type: foo
		names: Fred
	      - type: foo
		names: Ava

       then

	      yq '[.[] | select(.type == "foo") | .names] | flatten | sort | unique' sample.yml

       will output

	      - Ava
	      - Catherine
	      - Fred

   Explanation:
       • .[] | select(.type == "foo") | .names will select the array elements
	 of type “foo”

       • Splat .[] will unwrap the array and match all the items.  We need to
	 do this so we can work on the child items, for instance, filter items
	 out using the select operator.

       • But we still want the final results back into an array.  So after
	 we’re doing working on the children, we wrap everything back into an
	 array using square brackets around the expression.  [.[] |
	 select(.type == "foo") | .names]

       • Now have have an array of all the `names' values.  Which includes
	 arrays of strings as well as strings on their own.

       • Pipe | this array through flatten.  This will flatten nested arrays.
	 So now we have a flat list of all the name value strings

       • Next we pipe | that through sort and then unique to get a sorted,
	 unique list of the names!

       • See the flatten <https://mikefarah.gitbook.io/yq/operators/flatten>,
	 sort <https://mikefarah.gitbook.io/yq/operators/sort> and unique
	 <https://mikefarah.gitbook.io/yq/operators/unique> for more
	 information and examples.

   Export as environment variables (script), or any custom format
       Given a yaml document, lets output a script that will configure
       environment variables with that data.  This same approach can be used
       for exporting into custom formats.

       Given a sample.yml file of:

	      var0: string0
	      var1: string1
	      fruit:
		- apple
		- banana
		- peach

       then

	      yq '.[] |(
		  ( select(kind == "scalar") | key + "='\''" + . + "'\''"),
		  ( select(kind == "seq") | key + "=(" + (map("'\''" + . + "'\''") | join(",")) + ")")
	      )' sample.yml

       will output

	      var0='string0'
	      var1='string1'
	      fruit=('apple','banana','peach')

   Explanation:
       • .[] matches all top level elements

       • We need a string expression for each of the different types that will
	 produce the bash syntax, we’ll use the union operator, to join them
	 together

       • Scalars, we just need the key and quoted value: ( select(kind ==
	 "scalar") | key + "='" + . + "'")

       • Sequences (or arrays) are trickier, we need to quote each value and
	 join them with ,: map("'" + . + "'") | join(",")

   Custom format with nested data
       Like the previous example, but lets handle nested data structures.  In
       this custom example, we’re going to join the property paths with _.
       The important thing to keep in mind is that our expression is not
       recursive (despite the data structure being so).  Instead we match all
       elements on the tree and operate on them.

       Given a sample.yml file of:

	      simple: string0
	      simpleArray:
		- apple
		- banana
		- peach
	      deep:
		property: value
		array:
		  - cat

       then

	      yq '.. |(
		  ( select(kind == "scalar" and parent | kind != "seq") | (path | join("_")) + "='\''" + . + "'\''"),
		  ( select(kind == "seq") | (path | join("_")) + "=(" + (map("'\''" + . + "'\''") | join(",")) + ")")
	      )' sample.yml

       will output

	      simple='string0'
	      deep_property='value'
	      simpleArray=('apple','banana','peach')
	      deep_array=('cat')

   Explanation:
       • You’ll need to understand how the previous example works to
	 understand this extension.

       • .. matches all elements, instead of .[] from the previous example
	 that just matches top level elements.

       • Like before, we need a string expression for each of the different
	 types that will produce the bash syntax, we’ll use the union
	 operator, to join them together

       • This time, however, our expression matches every node in the data
	 structure.

       • We only want to print scalars that are not in arrays (because we
	 handle the separately), so well add and parent | kind != "seq" to the
	 select operator expression for scalars

       • We don’t just want the key any more, we want the full path.  So
	 instead of key we have path | join("_")

       • The expression for sequences follows the same logic

   Encode shell variables
       Note that comments are dropped and values will be enclosed in single
       quotes as needed.

       Given a sample.yml file of:

	      # comment
	      name: Mike Wazowski
	      eyes:
		color: turquoise
		number: 1
	      friends:
		- James P. Sullivan
		- Celia Mae

       then

	      yq -o=shell sample.yml

       will output

	      name='Mike Wazowski'
	      eyes_color=turquoise
	      eyes_number=1
	      friends_0='James P. Sullivan'
	      friends_1='Celia Mae'

   Encode shell variables: illegal variable names as key.
       Keys that would be illegal as variable keys are adapted.

       Given a sample.yml file of:

	      ascii_=_symbols: replaced with _
	      "ascii_ _controls": dropped (this example uses \t)
	      nonascii_א_characters: dropped
	      effort_expeñded_tò_preserve_accented_latin_letters: moderate (via unicode NFKD)

       then

	      yq -o=shell sample.yml

       will output

	      ascii___symbols='replaced with _'
	      ascii__controls='dropped (this example uses \t)'
	      nonascii__characters=dropped
	      effort_expended_to_preserve_accented_latin_letters='moderate (via unicode NFKD)'

   Encode shell variables: empty values, arrays and maps
       Empty values are encoded to empty variables, but empty arrays and maps
       are skipped.

       Given a sample.yml file of:

	      empty:
		value:
		array: []
		map:   {}

       then

	      yq -o=shell sample.yml

       will output

	      empty_value=

   Encode shell variables: single quotes in values
       Single quotes in values are encoded as `“'“’ (close single quote,
       double-quoted single quote, open single quote).

       Given a sample.yml file of:

	      name: Miles O'Brien

       then

	      yq -o=shell sample.yml

       will output

	      name='Miles O'"'"'Brien'

   Encode shell variables: custom separator
       Use –shell-key-separator to specify a custom separator between keys.
       This is useful when the original keys contain underscores.

       Given a sample.yml file of:

	      my_app:
		db_config:
		  host: localhost
		  port: 5432

       then

	      yq -o=shell --shell-key-separator="__" sample.yml

       will output

	      my_app__db_config__host=localhost
	      my_app__db_config__port=5432

TOML
       Decode from TOML.  Note that yq does not yet support outputting in TOML
       format (and therefore it cannot roundtrip)

   Parse: Simple
       Given a sample.toml file of:

	      A = "hello"
	      B = 12

       then

	      yq -oy '.' sample.toml

       will output

	      A: hello
	      B: 12

   Parse: Deep paths
       Given a sample.toml file of:

	      person.name = "hello"
	      person.address = "12 cat st"

       then

	      yq -oy '.' sample.toml

       will output

	      person:
		name: hello
		address: 12 cat st

   Encode: Scalar
       Given a sample.toml file of:

	      person.name = "hello"
	      person.address = "12 cat st"

       then

	      yq '.person.name' sample.toml

       will output

	      hello

   Parse: inline table
       Given a sample.toml file of:

	      name = { first = "Tom", last = "Preston-Werner" }

       then

	      yq -oy '.' sample.toml

       will output

	      name:
		first: Tom
		last: Preston-Werner

   Parse: Array Table
       Given a sample.toml file of:


	      [owner.contact]
	      name = "Tom Preston-Werner"
	      age = 36

	      [[owner.addresses]]
	      street = "first street"
	      suburb = "ok"

	      [[owner.addresses]]
	      street = "second street"
	      suburb = "nice"

       then

	      yq -oy '.' sample.toml

       will output

	      owner:
		contact:
		  name: Tom Preston-Werner
		  age: 36
		addresses:
		  - street: first street
		    suburb: ok
		  - street: second street
		    suburb: nice

   Parse: Array of Array Table
       Given a sample.toml file of:


	      [[fruits]]
	      name = "apple"
	      [[fruits.varieties]]  # nested array of tables
	      name = "red delicious"

       then

	      yq -oy '.' sample.toml

       will output

	      fruits:
		- name: apple
		  varieties:
		    - name: red delicious

   Parse: Empty Table
       Given a sample.toml file of:


	      [dependencies]

       then

	      yq -oy '.' sample.toml

       will output

	      dependencies: {}

XML
       Encode and decode to and from XML.  Whitespace is not conserved for
       round trips - but the order of the fields are.

       Consecutive xml nodes with the same name are assumed to be arrays.

       XML content data, attributes processing instructions and directives are
       all created as plain fields.

       This can be controlled by:

       Flag			 Default		   Sample XML
       ────────────────────────────────────────────────────────────────────────────
       --xml-attribute-prefix	 + (changing to +@ soon)   Legs in <cat legs="4"/>
       --xml-content-name	 +content		   Meow in <cat>Meow
							   <fur>true</true></cat>
       --xml-directive-name	 +directive		   <!DOCTYPE config system
							   "blah">
       --xml-proc-inst-prefix	 +p_			   <?xml version="1"?>

       {% hint style=“warning” %} Default Attribute Prefix will be changing in
       v4.30!  In order to avoid name conflicts (e.g. having an attribute
       named “content” will create a field that clashes with the default
       content name of “+content”) the attribute prefix will be changing to
       “+@”.

       This will affect users that have not set their own prefix and are not
       roundtripping XML changes.

       {% endhint %}

   Encoder / Decoder flag options
       In addition to the above flags, there are the following xml
       encoder/decoder options controlled by flags:

       Flag			 Default		   Description
       ────────────────────────────────────────────────────────────────────────────────────────────
       --xml-strict-mode	 false			   Strict mode enforces the requirements
							   of the XML specification. When switched
							   off the parser allows input containing
							   common mistakes. See
							   https://pkg.go.dev/encoding/xml#Decoder
							   the Golang xml decoder   for more
							   details.
       --xml-keep-namespace	 true			   Keeps the namespace of attributes
       --xml-raw-token		 true			   Does not verify that start and end
							   elements match and does not translate
							   name space prefixes to their
							   corresponding URLs.
       --xml-skip-proc-inst	 false			   Skips over processing instructions,
							   e.g. <?xml version="1"?>
       --xml-skip-directives	 false			   Skips over directives, e.g. <!DOCTYPE
							   config system "blah">

       See below for examples

   Parse xml: simple
       Notice how all the values are strings, see the next example on how you
       can fix that.

       Given a sample.xml file of:

	      <?xml version="1.0" encoding="UTF-8"?>
	      <cat>
		<says>meow</says>
		<legs>4</legs>
		<cute>true</cute>
	      </cat>

       then

	      yq -oy sample.xml

       will output

	      +p_xml: version="1.0" encoding="UTF-8"
	      cat:
		says: meow
		legs: "4"
		cute: "true"

   Parse xml: number
       All values are assumed to be strings when parsing XML, but you can use
       the from_yaml operator on all the strings values to autoparse into the
       correct type.

       Given a sample.xml file of:

	      <?xml version="1.0" encoding="UTF-8"?>
	      <cat>
		<says>meow</says>
		<legs>4</legs>
		<cute>true</cute>
	      </cat>

       then

	      yq -oy ' (.. | select(tag == "!!str")) |= from_yaml' sample.xml

       will output

	      +p_xml: version="1.0" encoding="UTF-8"
	      cat:
		says: meow
		legs: 4
		cute: true

   Parse xml: array
       Consecutive nodes with identical xml names are assumed to be arrays.

       Given a sample.xml file of:

	      <?xml version="1.0" encoding="UTF-8"?>
	      <animal>cat</animal>
	      <animal>goat</animal>

       then

	      yq -oy sample.xml

       will output

	      +p_xml: version="1.0" encoding="UTF-8"
	      animal:
		- cat
		- goat

   Parse xml: force as an array
       In XML, if your array has a single item, then yq doesn’t know its an
       array.  This is how you can consistently force it to be an array.  This
       handles the 3 scenarios of having nothing in the array, having a single
       item and having multiple.

       Given a sample.xml file of:

	      <zoo><animal>cat</animal></zoo>

       then

	      yq -oy '.zoo.animal |= ([] + .)' sample.xml

       will output

	      zoo:
		animal:
		  - cat

   Parse xml: force all as an array
       Given a sample.xml file of:

	      <zoo><thing><frog>boing</frog></thing></zoo>

       then

	      yq -oy '.. |= [] + .' sample.xml

       will output

	      - zoo:
		  - thing:
		      - frog:
			  - boing

   Parse xml: attributes
       Attributes are converted to fields, with the default attribute prefix
       `+'.  Use ’–xml-attribute-prefix` to set your own.

       Given a sample.xml file of:

	      <?xml version="1.0" encoding="UTF-8"?>
	      <cat legs="4">
		<legs>7</legs>
	      </cat>

       then

	      yq -oy sample.xml

       will output

	      +p_xml: version="1.0" encoding="UTF-8"
	      cat:
		+@legs: "4"
		legs: "7"

   Parse xml: attributes with content
       Content is added as a field, using the default content name of
       +content.  Use --xml-content-name to set your own.

       Given a sample.xml file of:

	      <?xml version="1.0" encoding="UTF-8"?>
	      <cat legs="4">meow</cat>

       then

	      yq -oy sample.xml

       will output

	      +p_xml: version="1.0" encoding="UTF-8"
	      cat:
		+content: meow
		+@legs: "4"

   Parse xml: content split between comments/children
       Multiple content texts are collected into a sequence.

       Given a sample.xml file of:

	      <root>  value  <!-- comment-->anotherValue <a>frog</a> cool!</root>

       then

	      yq -oy sample.xml

       will output

	      root:
		+content: # comment
		  - value
		  - anotherValue
		  - cool!
		a: frog

   Parse xml: custom dtd
       DTD entities are processed as directives.

       Given a sample.xml file of:


	      <?xml version="1.0"?>
	      <!DOCTYPE root [
	      <!ENTITY writer "Blah.">
	      <!ENTITY copyright "Blah">
	      ]>
	      <root>
		  <item>&writer;&copyright;</item>
	      </root>

       then

	      yq sample.xml

       will output

	      <?xml version="1.0"?>
	      <!DOCTYPE root [
	      <!ENTITY writer "Blah.">
	      <!ENTITY copyright "Blah">
	      ]>
	      <root>
		<item>&amp;writer;&amp;copyright;</item>
	      </root>

   Parse xml: skip custom dtd
       DTDs are directives, skip over directives to skip DTDs.

       Given a sample.xml file of:


	      <?xml version="1.0"?>
	      <!DOCTYPE root [
	      <!ENTITY writer "Blah.">
	      <!ENTITY copyright "Blah">
	      ]>
	      <root>
		  <item>&writer;&copyright;</item>
	      </root>

       then

	      yq --xml-skip-directives sample.xml

       will output

	      <?xml version="1.0"?>
	      <root>
		<item>&amp;writer;&amp;copyright;</item>
	      </root>

   Parse xml: with comments
       A best attempt is made to preserve comments.

       Given a sample.xml file of:


	      <!-- before cat -->
	      <cat>
		  <!-- in cat before -->
		  <x>3<!-- multi
	      line comment
	      for x --></x>
		  <!-- before y -->
		  <y>
		      <!-- in y before -->
		      <d><!-- in d before -->z<!-- in d after --></d>

		      <!-- in y after -->
		  </y>
		  <!-- in_cat_after -->
	      </cat>
	      <!-- after cat -->

       then

	      yq -oy sample.xml

       will output

	      # before cat
	      cat:
		# in cat before
		x: "3" # multi
		# line comment
		# for x
		# before y

		y:
		  # in y before
		  # in d before
		  d: z # in d after
		  # in y after
		# in_cat_after
	      # after cat

   Parse xml: keep attribute namespace
       Defaults to true

       Given a sample.xml file of:

	      <?xml version="1.0"?>
	      <map xmlns="some-namespace" xmlns:xsi="some-instance" xsi:schemaLocation="some-url">
		<item foo="bar">baz</item>
		<xsi:item>foobar</xsi:item>
	      </map>

       then

	      yq --xml-keep-namespace=false sample.xml

       will output

	      <?xml version="1.0"?>
	      <map xmlns="some-namespace" xsi="some-instance" schemaLocation="some-url">
		<item foo="bar">baz</item>
		<item>foobar</item>
	      </map>

       instead of

	      <?xml version="1.0"?>
	      <map xmlns="some-namespace" xmlns:xsi="some-instance" xsi:schemaLocation="some-url">
		<item foo="bar">baz</item>
		<xsi:item>foobar</xsi:item>
	      </map>

   Parse xml: keep raw attribute namespace
       Defaults to true

       Given a sample.xml file of:

	      <?xml version="1.0"?>
	      <map xmlns="some-namespace" xmlns:xsi="some-instance" xsi:schemaLocation="some-url">
		<item foo="bar">baz</item>
		<xsi:item>foobar</xsi:item>
	      </map>

       then

	      yq --xml-raw-token=false sample.xml

       will output

	      <?xml version="1.0"?>
	      <some-namespace:map xmlns="some-namespace" xmlns:xsi="some-instance" some-instance:schemaLocation="some-url">
		<some-namespace:item foo="bar">baz</some-namespace:item>
		<some-instance:item>foobar</some-instance:item>
	      </some-namespace:map>

       instead of

	      <?xml version="1.0"?>
	      <map xmlns="some-namespace" xmlns:xsi="some-instance" xsi:schemaLocation="some-url">
		<item foo="bar">baz</item>
		<xsi:item>foobar</xsi:item>
	      </map>

   Encode xml: simple
       Given a sample.yml file of:

	      cat: purrs

       then

	      yq -o=xml sample.yml

       will output

	      <cat>purrs</cat>

   Encode xml: array
       Given a sample.yml file of:

	      pets:
		cat:
		  - purrs
		  - meows

       then

	      yq -o=xml sample.yml

       will output

	      <pets>
		<cat>purrs</cat>
		<cat>meows</cat>
	      </pets>

   Encode xml: attributes
       Fields with the matching xml-attribute-prefix are assumed to be
       attributes.

       Given a sample.yml file of:

	      cat:
		+@name: tiger
		meows: true

       then

	      yq -o=xml sample.yml

       will output

	      <cat name="tiger">
		<meows>true</meows>
	      </cat>

   Encode xml: attributes with content
       Fields with the matching xml-content-name is assumed to be content.

       Given a sample.yml file of:

	      cat:
		+@name: tiger
		+content: cool

       then

	      yq -o=xml sample.yml

       will output

	      <cat name="tiger">cool</cat>

   Encode xml: comments
       A best attempt is made to copy comments to xml.

       Given a sample.yml file of:

	      #
	      # header comment
	      # above_cat
	      #
	      cat: # inline_cat
		# above_array
		array: # inline_array
		  - val1 # inline_val1
		  # above_val2
		  - val2 # inline_val2
	      # below_cat

       then

	      yq -o=xml sample.yml

       will output

	      <!--
	      header comment
	      above_cat
	      -->
	      <!-- inline_cat -->
	      <cat><!-- above_array inline_array -->
		<array>val1<!-- inline_val1 --></array>
		<array><!-- above_val2 -->val2<!-- inline_val2 --></array>
	      </cat><!-- below_cat -->

   Encode: doctype and xml declaration
       Use the special xml names to add/modify proc instructions and
       directives.

       Given a sample.yml file of:

	      +p_xml: version="1.0"
	      +directive: 'DOCTYPE config SYSTEM "/etc/iwatch/iwatch.dtd" '
	      apple:
		+p_coolioo: version="1.0"
		+directive: 'CATYPE meow purr puss '
		b: things

       then

	      yq -o=xml sample.yml

       will output

	      <?xml version="1.0"?>
	      <!DOCTYPE config SYSTEM "/etc/iwatch/iwatch.dtd" >
	      <apple><?coolioo version="1.0"?><!CATYPE meow purr puss >
		<b>things</b>
	      </apple>

   Round trip: with comments
       A best effort is made, but comment positions and white space are not
       preserved perfectly.

       Given a sample.xml file of:


	      <!-- before cat -->
	      <cat>
		  <!-- in cat before -->
		  <x>3<!-- multi
	      line comment
	      for x --></x>
		  <!-- before y -->
		  <y>
		      <!-- in y before -->
		      <d><!-- in d before -->z<!-- in d after --></d>

		      <!-- in y after -->
		  </y>
		  <!-- in_cat_after -->
	      </cat>
	      <!-- after cat -->

       then

	      yq sample.xml

       will output

	      <!-- before cat -->
	      <cat><!-- in cat before -->
		<x>3<!-- multi
	      line comment
	      for x --></x><!-- before y -->
		<y><!-- in y before
	      in d before -->
		  <d>z<!-- in d after --></d><!-- in y after -->
		</y><!-- in_cat_after -->
	      </cat><!-- after cat -->

   Roundtrip: with doctype and declaration
       yq parses XML proc instructions and directives into nodes.
       Unfortunately the underlying XML parser loses whitespace information.

       Given a sample.xml file of:

	      <?xml version="1.0"?>
	      <!DOCTYPE config SYSTEM "/etc/iwatch/iwatch.dtd" >
	      <apple>
		<?coolioo version="1.0"?>
		<!CATYPE meow purr puss >
		<b>things</b>
	      </apple>

       then

	      yq sample.xml

       will output

	      <?xml version="1.0"?>
	      <!DOCTYPE config SYSTEM "/etc/iwatch/iwatch.dtd" >
	      <apple><?coolioo version="1.0"?><!CATYPE meow purr puss >
		<b>things</b>
	      </apple>

AUTHORS
       Mike Farah.

									 YQ(1)
