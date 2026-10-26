// geolib/util/strings.goose — imported with `import util.strings;`
// Dots in an import path are directories: util.strings -> util/strings.goose,
// resolved relative to the root of the importing file's package.
import std;
namespace geolib;

fn bracket(s: const u8[:]) -> u8[>..] { str("[", s, "]") }
