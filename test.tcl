
proc combine { a b delimiter } {
  return "$a$delimiter $b"
}

proc echo { s } {
  puts $s!
}

set first hello
set "long var name" world

echo [combine $first ${long var name} ,]

