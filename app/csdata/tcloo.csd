title    "TclOO -- Cheat Sheet"
subtitle "oo::class, method, variable, mixin, next, self"
sections {
    {title "class definition" type code content {
        {oo::class create Animal {}}
        {oo::class create Dog {}}
        {    superclass Animal}
        {    variable name breed}
        {    constructor {n b} { set name $n; set breed $b }}
        {    method bark {} { puts "Woof! I am $name" }}
        {    method name {} { return $name }}
    }}
    {title "class & object" type table content {
        {{create class}  {oo::class create MyClass {}}        1}
        {instantiate     {set obj [MyClass new arg1]}         1}
        {{create named}  {MyClass create myobj arg1}          1}
        {{destroy obj}   {$obj destroy}                       1}
        {{destroy class} {MyClass destroy  ;# + all instances} 1}
        {{info class}    {info object class $obj}             1}
    }}
    {title "method types" type table content {
        {method       {method name {args} {body}}              1}
        {constructor  {constructor {args} {body}}              1}
        {destructor   {destructor {body}}                      1}
        {unexport     {unexport methodName}                    1}
        {export       {export methodName}                      1}
        {{self method} {self method name {args} {body}}        1}
        {forward      {forward mymethod other::proc}           1}
    }}
    {title "variable / self" type table content {
        {variable     {variable x y z  ;# declare instance vars}  1}
        {self         {self  -> object name}                       1}
        {{self class} {self class  -> class name}                  1}
        {{self ns}    {self namespace  -> object namespace}        1}
        {my           {my methodName  ;# call own method}          1}
    }}
    {title "inheritance" type table content {
        {superclass   {superclass Base1 Base2}                 1}
        {next         {next {*}$args  ;# call superclass method} 1}
        {mixin        {mixin Logging Serializable}             1}
        {isa          {$obj isa MyClass}                       1}
        {{info supers} {info class superclasses MyClass}       1}
        {{info mixins} {info class mixins MyClass}             1}
    }}
    {title "introspection" type table content {
        {methods      {info class methods MyClass}             1}
        {{all methods} {info class methods MyClass -all}       1}
        {instances    {info class instances MyClass}          1}
        {{is object}  {info object isa object $x}             1}
        {{is class}   {info object isa class $x}              1}
        {vars         {info object vars $obj}                 1}
    }}
    {title "patterns" type table content {
        {callback     {oo::objdefine $obj method cb {a} {body}} 1}
        {configure    {method configure {args} {array set _ $args}} 1}
        {copy         {oo::copy $obj ?newName?}                1}
        {namespace    {namespace eval [self namespace] { ... }} 1}
    }}
}
