///|
fn main {
  let mut path = ""
  let overwrite = @ref.new(false)
  @ArgParser.parse(
    [("--overwrite", "-w", Set(overwrite), "")],
    p => path = p,
    "",
    @env.args(),
  ) catch {
    e => {
      println(e)
      panic()
    }
  }
  let source = @fs.read_file_to_string(path) catch {
    e => {
      println(e)
      panic()
    }
  }
  let result = @formatter.format(source)
  if overwrite.val {
    @fs.write_string_to_file(result, path) catch {
      e => {
        println(e)
        panic()
      }
    }
  } else {
    println(result)
  }
}
