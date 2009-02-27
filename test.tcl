
proc combine { a b } {
  global delimiter
  return "$a$delimiter $b"
}

proc echo { s } {
  puts $s!
}

set delimiter ,
set first hello
set "long var name" world

echo [combine $first ${long var name}]

