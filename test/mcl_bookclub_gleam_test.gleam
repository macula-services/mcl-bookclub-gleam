import gleeunit
import gleeunit/should
import mcl_bookclub_gleam

pub fn main() {
  gleeunit.main()
}

pub fn hello_test() {
  mcl_bookclub_gleam.hello()
  |> should.equal("mcl-bookclub-gleam")
}
